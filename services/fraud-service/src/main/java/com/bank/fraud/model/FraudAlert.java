package com.bank.fraud.model;

import java.time.Instant;

public record FraudAlert(
    String userId,
    String reason,
    String severity,
    Instant detectedAt
) {
    public FraudAlert(String userId, String reason) {
        this(userId, reason, "HIGH", Instant.now());
    }
}
