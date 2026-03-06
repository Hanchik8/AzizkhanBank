package com.bank.account.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.bank.account.domain.Account;
import com.bank.account.domain.AccountTransaction;
import com.bank.account.domain.LedgerEntry;
import com.bank.account.outbox.OutboxEvent;
import com.bank.account.outbox.OutboxEventRepository;
import com.bank.account.outbox.TransactionCompletedEvent;
import com.bank.account.repository.AccountRepository;
import com.bank.account.repository.AccountTransactionRepository;
import com.bank.account.repository.LedgerEntryRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@Component
public class TransferTransactionHelper {

    private static final Logger LOGGER = LoggerFactory.getLogger(TransferTransactionHelper.class);
    private static final BigDecimal FEE_PERCENTAGE = new BigDecimal("0.01");
    private static final int BALANCE_SCALE = 4;
    private static final Long SYSTEM_ACCOUNT_ID = 9999L;

    private final AccountRepository accountRepository;
    private final AccountTransactionRepository accountTransactionRepository;
    private final LedgerEntryRepository ledgerEntryRepository;
    private final TransferLimitService transferLimitService;
    private final OutboxEventRepository outboxEventRepository;
    private final ObjectMapper objectMapper;

    public TransferTransactionHelper(
        AccountRepository accountRepository,
        AccountTransactionRepository accountTransactionRepository,
        LedgerEntryRepository ledgerEntryRepository,
        TransferLimitService transferLimitService,
        OutboxEventRepository outboxEventRepository,
        ObjectMapper objectMapper
    ) {
        this.accountRepository = accountRepository;
        this.accountTransactionRepository = accountTransactionRepository;
        this.ledgerEntryRepository = ledgerEntryRepository;
        this.transferLimitService = transferLimitService;
        this.outboxEventRepository = outboxEventRepository;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public TransferResult executeTransfer(TransferCommand command) {
        AccountTransaction existing = accountTransactionRepository
            .findByIdempotencyKeyForUpdate(command.idempotencyKey())
            .orElse(null);

        if (existing != null) {
            if (!existing.matches(command)) {
                throw new IllegalArgumentException("Idempotency-Key was already used with a different transfer payload");
            }
            return TransferResult.from(existing, true);
        }

        transferLimitService.checkAndRecordDailyLimit(command.userId(), command.amount());

        Account source = accountRepository.findByIdForUpdate(command.fromAccountId())
            .orElseThrow(() -> new IllegalArgumentException("Source account not found"));
        Account destination = accountRepository.findByIdForUpdate(command.toAccountId())
            .orElseThrow(() -> new IllegalArgumentException("Destination account not found"));
        Account systemAccount = accountRepository.findByIdForUpdate(SYSTEM_ACCOUNT_ID)
            .orElseThrow(() -> new IllegalArgumentException("System account not found"));

        requireNotFrozen(source, "Source account is frozen");
        requireNotFrozen(destination, "Destination account is frozen");

        BigDecimal amount = command.amount().setScale(BALANCE_SCALE, RoundingMode.HALF_UP);
        BigDecimal fee = amount.multiply(FEE_PERCENTAGE).setScale(BALANCE_SCALE, RoundingMode.HALF_UP);

        source.ensureCurrency(command.normalizedCurrency());
        destination.ensureCurrency(command.normalizedCurrency());
        systemAccount.ensureCurrency(command.normalizedCurrency());

        source.debit(amount.add(fee));
        destination.credit(amount);
        systemAccount.credit(fee);

        String transferId = UUID.randomUUID().toString();
        AccountTransaction tx = accountTransactionRepository.save(
            AccountTransaction.committed(transferId, command)
        );

        ledgerEntryRepository.save(LedgerEntry.debit(transferId, source.getId(), amount.add(fee), command.normalizedCurrency()));
        ledgerEntryRepository.save(LedgerEntry.credit(transferId, destination.getId(), amount, command.normalizedCurrency()));
        ledgerEntryRepository.save(LedgerEntry.credit(transferId, systemAccount.getId(), fee, command.normalizedCurrency()));

        outboxEventRepository.save(OutboxEvent.pending("Transaction", transferId, "TransactionCompletedEvent",
            serialize(new TransactionCompletedEvent(
                transferId, command.idempotencyKey(), command.userId(),
                source.getId(), destination.getId(), amount,
                command.normalizedCurrency(), tx.getCommittedAt()
            ))
        ));

        LOGGER.info("Transfer completed: id={} {}→{} {} {}", transferId,
            source.getId(), destination.getId(), amount, command.normalizedCurrency());

        return TransferResult.from(tx, false);
    }

    @Transactional
    public TransferResult executeInternalTransfer(TransferCommand command) {
        Account source = accountRepository.findByIdForUpdate(command.fromAccountId())
            .orElseThrow(() -> new IllegalArgumentException("Source account not found"));
        Account destination = accountRepository.findByIdForUpdate(command.toAccountId())
            .orElseThrow(() -> new IllegalArgumentException("Destination account not found"));

        BigDecimal amount = command.amount().setScale(BALANCE_SCALE, RoundingMode.HALF_UP);

        source.ensureCurrency(command.normalizedCurrency());
        destination.ensureCurrency(command.normalizedCurrency());

        source.debit(amount);
        destination.credit(amount);

        String transferId = UUID.randomUUID().toString();
        AccountTransaction tx = accountTransactionRepository.save(
            AccountTransaction.committed(transferId, command)
        );

        ledgerEntryRepository.save(LedgerEntry.debit(transferId, source.getId(), amount, command.normalizedCurrency()));
        ledgerEntryRepository.save(LedgerEntry.credit(transferId, destination.getId(), amount, command.normalizedCurrency()));

        return TransferResult.from(tx, false);
    }

    private static void requireNotFrozen(Account account, String message) {
        if (account.isFrozen()) {
            throw new org.springframework.security.access.AccessDeniedException(message);
        }
    }

    private String serialize(TransactionCompletedEvent event) {
        try {
            return objectMapper.writeValueAsString(event);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("Failed to serialize outbox event payload", ex);
        }
    }
}
