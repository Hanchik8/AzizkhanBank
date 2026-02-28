package com.bank.user.api;

import com.fasterxml.jackson.annotation.JsonProperty;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateUserRequest(
    @JsonProperty("phone_number")
    @NotBlank(message = "phone_number must not be blank")
    @Size(max = 32, message = "phone_number length must be <= 32")
    String phoneNumber
) {
}
