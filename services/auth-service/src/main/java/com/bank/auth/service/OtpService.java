package com.bank.auth.service;

import com.bank.auth.client.UserServiceClient;
import com.bank.auth.messaging.AuthEventPublisher;
import java.security.SecureRandom;
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class OtpService {

    private static final SecureRandom OTP_RANDOM = new SecureRandom();
    private static final Duration OTP_TTL = Duration.ofMinutes(3);

    private final StringRedisTemplate stringRedisTemplate;
    private final AuthEventPublisher authEventPublisher;
    private final UserServiceClient userServiceClient;
    private final JwtService jwtService;

    public OtpService(
        StringRedisTemplate stringRedisTemplate,
        AuthEventPublisher authEventPublisher,
        UserServiceClient userServiceClient,
        JwtService jwtService
    ) {
        this.stringRedisTemplate = stringRedisTemplate;
        this.authEventPublisher = authEventPublisher;
        this.userServiceClient = userServiceClient;
        this.jwtService = jwtService;
    }

    public void sendOtp(String phoneNumber) {
        String normalizedPhone = phoneNumber.trim();
        String otpCode = generateOtpCode();
        String redisKey = "otp:" + normalizedPhone;

        stringRedisTemplate.opsForValue().set(redisKey, otpCode, OTP_TTL);
        authEventPublisher.publishOtp(normalizedPhone, otpCode);
    }

    public String verifyOtp(String phoneNumber, String code) {
        String normalizedPhone = phoneNumber.trim();
        String normalizedCode = code.trim();
        String redisKey = "otp:" + normalizedPhone;

        String expectedCode = stringRedisTemplate.opsForValue().get(redisKey);
        if (expectedCode == null || !expectedCode.equals(normalizedCode)) {
            throw new InvalidOtpException();
        }

        stringRedisTemplate.delete(redisKey);
        var userId = userServiceClient.findOrCreateUserIdByPhone(normalizedPhone);
        return jwtService.generateRegistrationToken(userId);
    }

    private String generateOtpCode() {
        int value = OTP_RANDOM.nextInt(1_000_000);
        return String.format("%06d", value);
    }
}
