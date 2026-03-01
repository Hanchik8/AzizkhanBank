package com.bank.account.api;

import java.math.BigDecimal;
import java.time.Instant;

public record TransactionHistoryResponse(
    String transferId,
    BigDecimal amount,
    String currency,
    String type,
    Instant timestamp
) {
}
