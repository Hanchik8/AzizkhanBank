package com.bank.account.service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bank.account.config.RedisLockProperties;
import com.bank.account.domain.Account;
import com.bank.account.domain.AccountTransaction;
import com.bank.account.domain.LedgerEntry;
import com.bank.account.repository.AccountRepository;
import com.bank.account.repository.AccountTransactionRepository;
import com.bank.account.repository.LedgerEntryRepository;
import com.bank.account.outbox.OutboxEvent;
import com.bank.account.outbox.OutboxEventRepository;
import com.bank.account.outbox.TransactionCompletedEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class AccountTransferService {

    private static final BigDecimal FEE_PERCENTAGE = new BigDecimal("0.01");
    private static final Long SYSTEM_ACCOUNT_ID = 9999L;

    private final AccountRepository accountRepository;
    private final AccountTransactionRepository accountTransactionRepository;
    private final LedgerEntryRepository ledgerEntryRepository;
    private final TransferLimitService transferLimitService;
    private final OutboxEventRepository outboxEventRepository;
    private final RedissonClient redissonClient;
    private final RedisLockProperties redisLockProperties;
    private final ObjectMapper objectMapper;

    public AccountTransferService(
        AccountRepository accountRepository,
        AccountTransactionRepository accountTransactionRepository,
        LedgerEntryRepository ledgerEntryRepository,
        TransferLimitService transferLimitService,
        OutboxEventRepository outboxEventRepository,
        RedissonClient redissonClient,
        RedisLockProperties redisLockProperties,
        ObjectMapper objectMapper
    ) {
        this.accountRepository = accountRepository;
        this.accountTransactionRepository = accountTransactionRepository;
        this.ledgerEntryRepository = ledgerEntryRepository;
        this.transferLimitService = transferLimitService;
        this.outboxEventRepository = outboxEventRepository;
        this.redissonClient = redissonClient;
        this.redisLockProperties = redisLockProperties;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public TransferResult transfer(TransferCommand command) {
        command.validate();
        verifySourceAccountOwnership(command);
        transferLimitService.checkAndRecordDailyLimit(command.userId(), command.amount());

        List<RLock> locks = acquireAccountLocks(command.fromAccountId(), command.toAccountId(), SYSTEM_ACCOUNT_ID);
        try {
            AccountTransaction existingByIdempotency = accountTransactionRepository
                .findByIdempotencyKeyForUpdate(command.idempotencyKey())
                .orElse(null);

            if (existingByIdempotency != null) {
                validateIdempotentReplay(command, existingByIdempotency);
                return TransferResult.from(existingByIdempotency, true);
            }

            Account source = accountRepository.findByIdForUpdate(command.fromAccountId())
                .orElseThrow(() -> new IllegalArgumentException("Source account not found"));
            Account destination = accountRepository.findByIdForUpdate(command.toAccountId())
                .orElseThrow(() -> new IllegalArgumentException("Destination account not found"));
            Account systemAccount = accountRepository.findByIdForUpdate(SYSTEM_ACCOUNT_ID)
                .orElseThrow(() -> new IllegalArgumentException("System account not found"));

            ensureSourceAccountNotFrozen(source);

            BigDecimal feeAmount = command.amount().multiply(FEE_PERCENTAGE);
            BigDecimal totalDebitAmount = command.amount().add(feeAmount);

            source.ensureCurrency(command.normalizedCurrency());
            destination.ensureCurrency(command.normalizedCurrency());
            systemAccount.ensureCurrency(command.normalizedCurrency());

            if (source.getBalance().compareTo(totalDebitAmount) < 0) {
                throw new IllegalStateException("Insufficient funds for transfer amount and fee");
            }

            source.debit(totalDebitAmount);
            destination.credit(command.amount());
            systemAccount.credit(feeAmount);

            String transferId = UUID.randomUUID().toString();

            AccountTransaction committedTransaction = accountTransactionRepository.save(
                AccountTransaction.committed(transferId, command)
            );

            ledgerEntryRepository.save(LedgerEntry.debit(
                transferId,
                source.getId(),
                command.amount(),
                command.normalizedCurrency()
            ));
            ledgerEntryRepository.save(LedgerEntry.credit(
                transferId,
                destination.getId(),
                command.amount(),
                command.normalizedCurrency()
            ));
            ledgerEntryRepository.save(LedgerEntry.debit(
                transferId,
                source.getId(),
                feeAmount,
                command.normalizedCurrency()
            ));
            ledgerEntryRepository.save(LedgerEntry.credit(
                transferId,
                systemAccount.getId(),
                feeAmount,
                command.normalizedCurrency()
            ));

            TransactionCompletedEvent event = new TransactionCompletedEvent(
                transferId,
                command.idempotencyKey(),
                source.getId(),
                destination.getId(),
                command.amount(),
                command.normalizedCurrency(),
                committedTransaction.getCommittedAt()
            );

            outboxEventRepository.save(OutboxEvent.pending(
                "Transaction",
                transferId,
                "TransactionCompletedEvent",
                serializeEvent(event)
            ));

            return TransferResult.from(committedTransaction, false);
        } finally {
            releaseLocks(locks);
        }
    }

    private void verifySourceAccountOwnership(TransferCommand command) {
        String sourceAccountOwnerId = accountRepository.findCustomerIdById(command.fromAccountId())
            .orElseThrow(() -> new IllegalArgumentException("Source account not found"));

        if (!sourceAccountOwnerId.equals(command.userId())) {
            throw new AccessDeniedException("Source account does not belong to authenticated user");
        }
    }

    private void ensureSourceAccountNotFrozen(Account source) {
        if (source.isFrozen()) {
            throw new AccessDeniedException("Source account is frozen");
        }
    }

    private List<RLock> acquireAccountLocks(Long... accountIds) {
        List<Long> orderedIds = java.util.Arrays.stream(accountIds)
            .distinct()
            .sorted(Comparator.naturalOrder())
            .toList();

        List<RLock> acquired = new ArrayList<>(orderedIds.size());
        try {
            for (Long accountId : orderedIds) {
                RLock lock = redissonClient.getLock("account:lock:" + accountId);
                boolean locked = lock.tryLock(
                    redisLockProperties.getWaitTimeout().toMillis(),
                    redisLockProperties.getLeaseTimeout().toMillis(),
                    TimeUnit.MILLISECONDS
                );
                if (!locked) {
                    throw new IllegalStateException("Failed to acquire lock for account " + accountId);
                }
                acquired.add(lock);
            }
            return acquired;
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            releaseLocks(acquired);
            throw new IllegalStateException("Interrupted while acquiring distributed lock", ex);
        } catch (RuntimeException ex) {
            releaseLocks(acquired);
            throw ex;
        }
    }

    private void releaseLocks(List<RLock> locks) {
        for (int i = locks.size() - 1; i >= 0; i--) {
            RLock lock = locks.get(i);
            try {
                if (lock.isHeldByCurrentThread()) {
                    lock.unlock();
                }
            } catch (RuntimeException ignored) {
                // Prefer preserving the business exception; rely on lease timeout as backstop.
            }
        }
    }

    private static void validateIdempotentReplay(TransferCommand command, AccountTransaction existing) {
        if (existing.matches(command)) {
            return;
        }

        throw new IllegalArgumentException(
            "Idempotency-Key was already used with a different transfer payload"
        );
    }

    private String serializeEvent(TransactionCompletedEvent event) {
        try {
            return objectMapper.writeValueAsString(event);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("Failed to serialize outbox event payload", ex);
        }
    }
}
