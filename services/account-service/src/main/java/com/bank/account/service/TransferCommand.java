package com.bank.account.service;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Locale;

public record TransferCommand(
    String userId,
    String idempotencyKey,
    Long fromAccountId,
    Long toAccountId,
    BigDecimal amount,
    String currency,
    Instant requestedAt
) {

    public void validate() {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("userId is required");
        }
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            throw new IllegalArgumentException("Idempotency-Key is required");
        }
        if (fromAccountId == null || toAccountId == null) {
            throw new IllegalArgumentException("fromAccountId/toAccountId are required");
        }
        if (fromAccountId.equals(toAccountId)) {
            throw new IllegalArgumentException("Source and destination accounts must differ");
        }
        if (amount == null || amount.signum() <= 0) {
            throw new IllegalArgumentException("Transfer amount must be positive");
        }
        if (currency == null || currency.length() != 3) {
            throw new IllegalArgumentException("currency must be ISO-4217 alpha-3");
        }
    }

    public String normalizedCurrency() {
        return currency.toUpperCase(Locale.ROOT);
    }

    public Instant requestedAt() {
        return requestedAt == null ? Instant.now() : requestedAt;
    }
}
