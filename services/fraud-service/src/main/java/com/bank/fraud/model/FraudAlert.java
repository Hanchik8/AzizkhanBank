package com.bank.fraud.model;

public record FraudAlert(
    String userId,
    String reason
) {
}
