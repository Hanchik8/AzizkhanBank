package com.bank.account.service;

import java.util.List;

import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bank.account.api.AccountResponse;
import com.bank.account.api.TransactionHistoryResponse;
import com.bank.account.domain.Account;
import com.bank.account.repository.AccountRepository;
import com.bank.account.repository.LedgerEntryRepository;

@Service
public class AccountQueryService {

    private final AccountRepository accountRepository;
    private final LedgerEntryRepository ledgerEntryRepository;

    public AccountQueryService(
        AccountRepository accountRepository,
        LedgerEntryRepository ledgerEntryRepository
    ) {
        this.accountRepository = accountRepository;
        this.ledgerEntryRepository = ledgerEntryRepository;
    }

    @Transactional(readOnly = true)
    public List<AccountResponse> getUserAccounts(String userId) {
        return accountRepository.findAllByClientId(userId).stream()
            .map(account -> new AccountResponse(
                account.getId(),
                account.getCurrency(),
                account.getBalance(),
                "ACTIVE"
            ))
            .toList();
    }

    @Transactional(readOnly = true)
    public List<TransactionHistoryResponse> getAccountHistory(String userId, Long accountId) {
        Account account = accountRepository.findById(accountId)
            .orElseThrow(() -> new IllegalArgumentException("Account not found"));

        if (!account.getCustomerId().equals(userId)) {
            throw new AccessDeniedException("Account does not belong to authenticated user");
        }

        return ledgerEntryRepository.findAllByAccountIdOrderByCreatedAtDesc(accountId).stream()
            .map(entry -> new TransactionHistoryResponse(
                entry.getTransferId(),
                entry.getAmount(),
                entry.getCurrency(),
                entry.getEntryType().name(),
                entry.getCreatedAt()
            ))
            .toList();
    }
}
