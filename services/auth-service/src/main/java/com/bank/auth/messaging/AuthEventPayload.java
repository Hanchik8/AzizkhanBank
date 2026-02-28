package com.bank.auth.messaging;

public record AuthEventPayload(
    String phoneNumber,
    String otpCode
) {
}
