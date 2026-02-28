package com.bank.user.api;

import java.time.Instant;
import java.util.UUID;

import com.bank.user.domain.User;
import com.fasterxml.jackson.annotation.JsonProperty;

public record UserResponse(
    UUID id,
    @JsonProperty("phone_number")
    String phoneNumber,
    String status,
    @JsonProperty("created_at")
    Instant createdAt
) {

    public static UserResponse from(User user) {
        return new UserResponse(
            user.getId(),
            user.getPhoneNumber(),
            user.getStatus(),
            user.getCreatedAt()
        );
    }
}
