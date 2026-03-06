package com.bank.user.api;

import java.net.URI;
import java.nio.charset.StandardCharsets;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriUtils;
import org.springframework.web.server.ResponseStatusException;

import com.bank.user.domain.User;
import com.bank.user.service.UserService;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/internal/v1/users")
@Validated
public class UserInternalController {

    private final UserService userService;
    private final String internalApiKey;

    public UserInternalController(
        UserService userService,
        @Value("${app.internal-api-key:}") String internalApiKey
    ) {
        this.userService = userService;
        this.internalApiKey = internalApiKey;
    }

    private void verifyApiKey(String providedKey) {
        if (internalApiKey != null && !internalApiKey.isBlank()) {
            if (!internalApiKey.equals(providedKey)) {
                throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid or missing API key");
            }
        }
    }

    @PostMapping
    public ResponseEntity<UserResponse> createUser(
        @RequestHeader(name = "X-Internal-Api-Key", required = false) String apiKey,
        @Valid @RequestBody CreateUserRequest request
    ) {
        verifyApiKey(apiKey);
        User createdUser = userService.createByPhoneNumber(request.phoneNumber());
        String encodedPhone = UriUtils.encodePathSegment(createdUser.getPhoneNumber(), StandardCharsets.UTF_8);
        URI location = URI.create("/internal/v1/users/by-phone/" + encodedPhone);
        return ResponseEntity.created(location).body(UserResponse.from(createdUser));
    }

    @GetMapping("/by-phone/{phone}")
    public UserResponse findByPhone(
        @RequestHeader(name = "X-Internal-Api-Key", required = false) String apiKey,
        @PathVariable("phone") @NotBlank String phone
    ) {
        verifyApiKey(apiKey);
        User user = userService.findByPhoneNumber(phone);
        return UserResponse.from(user);
    }
}
