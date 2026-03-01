package com.bank.account.api;

import java.math.BigDecimal;

public record AccountResponse(
    Long id,
    String currency,
    BigDecimal balance,
    String status
) {
}
