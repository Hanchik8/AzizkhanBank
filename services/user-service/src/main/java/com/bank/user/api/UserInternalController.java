package com.bank.user.api;

import java.net.URI;
import java.nio.charset.StandardCharsets;

import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriUtils;

import com.bank.user.domain.User;
import com.bank.user.service.UserService;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/internal/v1/users")
@Validated
public class UserInternalController {

    private final UserService userService;

    public UserInternalController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public ResponseEntity<UserResponse> createUser(@Valid @RequestBody CreateUserRequest request) {
        User createdUser = userService.createByPhoneNumber(request.phoneNumber());
        String encodedPhone = UriUtils.encodePathSegment(createdUser.getPhoneNumber(), StandardCharsets.UTF_8);
        URI location = URI.create("/internal/v1/users/by-phone/" + encodedPhone);
        return ResponseEntity.created(location).body(UserResponse.from(createdUser));
    }

    @GetMapping("/by-phone/{phone}")
    public UserResponse findByPhone(@PathVariable("phone") @NotBlank String phone) {
        User user = userService.findByPhoneNumber(phone);
        return UserResponse.from(user);
    }
}
