package com.bank.auth.api;

import com.bank.auth.service.DeviceBindingService;
import com.bank.auth.service.JwtService;
import com.bank.auth.service.OtpService;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final OtpService otpService;
    private final DeviceBindingService deviceBindingService;

    public AuthController(OtpService otpService, DeviceBindingService deviceBindingService) {
        this.otpService = otpService;
        this.deviceBindingService = deviceBindingService;
    }

    @PostMapping("/send-otp")
    public ResponseEntity<Void> sendOtp(@Valid @RequestBody SendOtpRequest request) {
        otpService.sendOtp(request.phoneNumber());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<VerifyOtpResponse> verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
        String token = otpService.verifyOtp(request.phoneNumber(), request.code());
        return ResponseEntity.ok(new VerifyOtpResponse(token));
    }

    @PostMapping("/device/bind")
    public ResponseEntity<DeviceBindResponse> bindDevice(
        @RequestHeader(HttpHeaders.AUTHORIZATION) String authorizationHeader,
        @Valid @RequestBody DeviceBindRequest request
    ) {
        JwtService.TokenPair tokenPair = deviceBindingService.bindDevice(
            authorizationHeader,
            request.deviceId(),
            request.publicKey()
        );

        return ResponseEntity.ok(new DeviceBindResponse(
            tokenPair.accessToken(),
            tokenPair.refreshToken(),
            "Bearer"
        ));
    }
}
