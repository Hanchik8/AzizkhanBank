package com.bank.notification.messaging;

import com.fasterxml.jackson.annotation.JsonProperty;

public record AuthEventPayload(
    @JsonProperty("phoneNumber")
    String phoneNumber,
    @JsonProperty("otpCode")
    String otpCode
) {
}
