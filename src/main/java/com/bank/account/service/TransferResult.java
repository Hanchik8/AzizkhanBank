package com.bank.account.service;

import java.math.BigDecimal;
import java.time.Instant;

import com.bank.account.domain.AccountTransaction;
import com.bank.account.domain.TransactionStatus;

public record TransferResult(
    String transferId,
    String idempotencyKey,
    Long fromAccountId,
    Long toAccountId,
    BigDecimal amount,
    String currency,
    TransactionStatus status,
    Instant committedAt,
    boolean idempotentReplay
) {

    public static TransferResult from(AccountTransaction transaction, boolean idempotentReplay) {
        return new TransferResult(
            transaction.getTransferId(),
            transaction.getIdempotencyKey(),
            transaction.getFromAccountId(),
            transaction.getToAccountId(),
            transaction.getAmount(),
            transaction.getCurrency(),
            transaction.getStatus(),
            transaction.getCommittedAt(),
            idempotentReplay
        );
    }
}
