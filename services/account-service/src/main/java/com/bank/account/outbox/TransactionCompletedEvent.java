package com.bank.account.outbox;

import java.math.BigDecimal;
import java.time.Instant;

import com.bank.account.domain.AccountTransaction;

public record TransactionCompletedEvent(
    String transferId,
    String idempotencyKey,
    String userId,
    Long fromAccountId,
    Long toAccountId,
    BigDecimal amount,
    String currency,
    Instant committedAt
) {

    public static TransactionCompletedEvent from(AccountTransaction transaction, String userId) {
        return new TransactionCompletedEvent(
            transaction.getTransferId(),
            transaction.getIdempotencyKey(),
            userId,
            transaction.getFromAccountId(),
            transaction.getToAccountId(),
            transaction.getAmount(),
            transaction.getCurrency(),
            transaction.getCommittedAt()
        );
    }
}
