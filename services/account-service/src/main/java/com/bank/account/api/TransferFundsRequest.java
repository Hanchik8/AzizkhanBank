package com.bank.account.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record TransferFundsRequest(
    @NotNull Long fromAccountId,
    @NotNull Long toAccountId,
    @NotNull @DecimalMin(value = "0.0001") BigDecimal amount,
    @NotNull @Pattern(regexp = "^[A-Z]{3}$", message = "currency must be ISO-4217 alpha-3") String currency
) {
}
