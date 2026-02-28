package com.bank.auth.api;

import jakarta.validation.constraints.NotBlank;

public record DeviceBindRequest(
    @NotBlank(message = "deviceId must not be blank")
    String deviceId,
    @NotBlank(message = "publicKey must not be blank")
    String publicKey
) {
}
