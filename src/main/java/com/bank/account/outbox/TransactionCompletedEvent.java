package com.bank.account.outbox;

import java.math.BigDecimal;
import java.time.Instant;

import com.bank.account.domain.AccountTransaction;

public record TransactionCompletedEvent(
    String transferId,
    String idempotencyKey,
    Long fromAccountId,
    Long toAccountId,
    BigDecimal amount,
    String currency,
    Instant committedAt
) {

    public static TransactionCompletedEvent from(AccountTransaction transaction) {
        return new TransactionCompletedEvent(
            transaction.getTransferId(),
            transaction.getIdempotencyKey(),
            transaction.getFromAccountId(),
            transaction.getToAccountId(),
            transaction.getAmount(),
            transaction.getCurrency(),
            transaction.getCommittedAt()
        );
    }
}
