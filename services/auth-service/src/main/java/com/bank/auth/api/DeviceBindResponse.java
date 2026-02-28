package com.bank.auth.api;

public record DeviceBindResponse(
    String accessToken,
    String refreshToken,
    String tokenType
) {
}
