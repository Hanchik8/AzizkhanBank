package com.bank.account.api;

import java.math.BigDecimal;
import java.time.Instant;

import com.bank.account.domain.TransactionStatus;
import com.bank.account.service.TransferResult;

public record TransferFundsResponse(
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

    public static TransferFundsResponse from(TransferResult transferResult) {
        return new TransferFundsResponse(
            transferResult.transferId(),
            transferResult.idempotencyKey(),
            transferResult.fromAccountId(),
            transferResult.toAccountId(),
            transferResult.amount(),
            transferResult.currency(),
            transferResult.status(),
            transferResult.committedAt(),
            transferResult.idempotentReplay()
        );
    }
}
