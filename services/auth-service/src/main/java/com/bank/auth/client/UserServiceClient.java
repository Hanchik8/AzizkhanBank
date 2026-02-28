package com.bank.auth.client;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriUtils;

@Component
public class UserServiceClient {

    private final RestTemplate restTemplate;
    private final String baseUrl;

    public UserServiceClient(
        RestTemplate restTemplate,
        @Value("${app.user-service.base-url:http://localhost:8081}") String baseUrl
    ) {
        this.restTemplate = restTemplate;
        this.baseUrl = baseUrl;
    }

    public UUID findOrCreateUserIdByPhone(String phoneNumber) {
        UserServiceUserResponse existingUser = findByPhone(phoneNumber);
        if (existingUser != null && existingUser.id() != null) {
            return existingUser.id();
        }

        UserServiceUserResponse createdUser = createUser(phoneNumber);
        if (createdUser.id() == null) {
            throw new IllegalStateException("User-service returned empty user id");
        }

        return createdUser.id();
    }

    private UserServiceUserResponse findByPhone(String phoneNumber) {
        String encodedPhone = UriUtils.encodePathSegment(phoneNumber, StandardCharsets.UTF_8);
        URI uri = URI.create(baseUrl + "/internal/v1/users/by-phone/" + encodedPhone);

        try {
            ResponseEntity<UserServiceUserResponse> response = restTemplate.exchange(
                uri,
                HttpMethod.GET,
                HttpEntity.EMPTY,
                UserServiceUserResponse.class
            );
            return response.getBody();
        } catch (HttpClientErrorException.NotFound notFound) {
            return null;
        }
    }

    private UserServiceUserResponse createUser(String phoneNumber) {
        URI uri = URI.create(baseUrl + "/internal/v1/users");
        UserServiceCreateUserRequest request = new UserServiceCreateUserRequest(phoneNumber);

        try {
            return restTemplate.postForObject(uri, request, UserServiceUserResponse.class);
        } catch (HttpClientErrorException.Conflict conflict) {
            UserServiceUserResponse existingUser = findByPhone(phoneNumber);
            if (existingUser == null || existingUser.id() == null) {
                throw conflict;
            }
            return existingUser;
        }
    }

    private record UserServiceCreateUserRequest(
        @JsonProperty("phone_number")
        String phoneNumber
    ) {
    }

    private record UserServiceUserResponse(
        UUID id,
        @JsonProperty("phone_number")
        String phoneNumber,
        String status,
        @JsonProperty("created_at")
        Instant createdAt
    ) {
    }
}
