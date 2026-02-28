package com.bank.auth.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SendOtpRequest(
    @NotBlank(message = "phoneNumber must not be blank")
    @Size(max = 32, message = "phoneNumber length must be <= 32")
    String phoneNumber
) {
}
