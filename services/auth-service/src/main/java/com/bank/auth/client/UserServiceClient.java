package com.bank.auth.client;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
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
    private final String internalApiKey;

    public UserServiceClient(
        RestTemplate restTemplate,
        @Value("${app.user-service.base-url:http://localhost:8081}") String baseUrl,
        @Value("${app.internal-api-key:}") String internalApiKey
    ) {
        this.restTemplate = restTemplate;
        this.baseUrl = baseUrl;
        this.internalApiKey = internalApiKey;
    }

    private HttpEntity<?> withApiKey() {
        return withApiKey(null);
    }

    private <T> HttpEntity<T> withApiKey(T body) {
        HttpHeaders headers = new HttpHeaders();
        if (internalApiKey != null && !internalApiKey.isBlank()) {
            headers.set("X-Internal-Api-Key", internalApiKey);
        }
        return new HttpEntity<>(body, headers);
    }

    public UUID findOrCreateUserIdByPhone(String phoneNumber) {
        return retryOnFailure(() -> doFindOrCreate(phoneNumber), 3, 500);
    }

    private UUID doFindOrCreate(String phoneNumber) {
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

    private <T> T retryOnFailure(java.util.function.Supplier<T> action, int maxAttempts, long baseDelayMs) {
        Exception lastException = null;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                return action.get();
            } catch (org.springframework.web.client.ResourceAccessException ex) {
                lastException = ex;
                if (attempt < maxAttempts) {
                    try { Thread.sleep(baseDelayMs * attempt); }
                    catch (InterruptedException ie) { Thread.currentThread().interrupt(); throw new IllegalStateException(ie); }
                }
            }
        }
        throw new IllegalStateException("user-service unavailable after " + maxAttempts + " attempts", lastException);
    }

    private UserServiceUserResponse findByPhone(String phoneNumber) {
        String encodedPhone = UriUtils.encodePathSegment(phoneNumber, StandardCharsets.UTF_8);
        URI uri = URI.create(baseUrl + "/internal/v1/users/by-phone/" + encodedPhone);

        try {
            ResponseEntity<UserServiceUserResponse> response = restTemplate.exchange(
                uri,
                HttpMethod.GET,
                withApiKey(),
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
            ResponseEntity<UserServiceUserResponse> resp = restTemplate.exchange(
                uri, HttpMethod.POST, withApiKey(request), UserServiceUserResponse.class);
            return resp.getBody();
        } catch (HttpClientErrorException.Conflict conflict) {
            for (int attempt = 0; attempt < 3; attempt++) {
                UserServiceUserResponse existingUser = findByPhone(phoneNumber);
                if (existingUser != null && existingUser.id() != null) {
                    return existingUser;
                }
                try {
                    Thread.sleep(100L * (attempt + 1));
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw conflict;
                }
            }
            throw conflict;
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
