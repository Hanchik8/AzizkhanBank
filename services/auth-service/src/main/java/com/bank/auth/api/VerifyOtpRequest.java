package com.bank.auth.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record VerifyOtpRequest(
    @NotBlank(message = "phoneNumber must not be blank")
    @Size(max = 32, message = "phoneNumber length must be <= 32")
    String phoneNumber,
    @NotBlank(message = "code must not be blank")
    @Pattern(regexp = "^\\d{6}$", message = "code must be exactly 6 digits")
    String code
) {
}
