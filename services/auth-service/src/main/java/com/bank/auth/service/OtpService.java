package com.bank.auth.service;

import com.bank.auth.client.UserServiceClient;
import com.bank.auth.messaging.AuthEventPublisher;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class OtpService {

    private static final SecureRandom OTP_RANDOM = new SecureRandom();
    private static final Duration OTP_TTL = Duration.ofMinutes(3);
    private static final int MAX_VERIFY_ATTEMPTS = 5;

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
        String normalizedPhone = normalizePhone(phoneNumber);
        String otpCode = generateOtpCode();
        String redisKey = otpKey(normalizedPhone);
        String attemptsKey = attemptsKey(normalizedPhone);

        stringRedisTemplate.opsForValue().set(redisKey, otpCode, OTP_TTL);
        stringRedisTemplate.delete(attemptsKey);
        authEventPublisher.publishOtp(normalizedPhone, otpCode);
    }

    public String verifyOtp(String phoneNumber, String code) {
        String normalizedPhone = normalizePhone(phoneNumber);
        String normalizedCode = code.trim();
        String redisKey = otpKey(normalizedPhone);
        String attemptsKey = attemptsKey(normalizedPhone);

        checkAttemptLimit(attemptsKey, redisKey);

        String expectedCode = stringRedisTemplate.opsForValue().get(redisKey);
        if (expectedCode == null || !constantTimeEquals(expectedCode, normalizedCode)) {
            recordFailedAttempt(attemptsKey);
            throw new InvalidOtpException();
        }

        stringRedisTemplate.delete(redisKey);
        stringRedisTemplate.delete(attemptsKey);
        var userId = userServiceClient.findOrCreateUserIdByPhone(normalizedPhone);
        return jwtService.generateRegistrationToken(userId);
    }

    private void checkAttemptLimit(String attemptsKey, String otpKey) {
        String attemptsStr = stringRedisTemplate.opsForValue().get(attemptsKey);
        if (attemptsStr != null) {
            int attempts = Integer.parseInt(attemptsStr);
            if (attempts >= MAX_VERIFY_ATTEMPTS) {
                stringRedisTemplate.delete(otpKey);
                stringRedisTemplate.delete(attemptsKey);
                throw new InvalidOtpException("Too many failed attempts. Please request a new code.");
            }
        }
    }

    private void recordFailedAttempt(String attemptsKey) {
        Long count = stringRedisTemplate.opsForValue().increment(attemptsKey);
        if (count != null && count == 1L) {
            stringRedisTemplate.expire(attemptsKey, OTP_TTL);
        }
    }

    private static boolean constantTimeEquals(String a, String b) {
        return MessageDigest.isEqual(
            a.getBytes(java.nio.charset.StandardCharsets.UTF_8),
            b.getBytes(java.nio.charset.StandardCharsets.UTF_8)
        );
    }

    private static String otpKey(String phone) {
        return "otp:" + phone;
    }

    private static String attemptsKey(String phone) {
        return "otp:attempts:" + phone;
    }

    private static String normalizePhone(String phoneNumber) {
        String cleaned = phoneNumber.trim().replaceAll("[\\s\\-()]+", "");
        if (cleaned.startsWith("8") && cleaned.length() == 11) {
            cleaned = "+7" + cleaned.substring(1);
        }
        if (!cleaned.startsWith("+")) {
            cleaned = "+" + cleaned;
        }
        return cleaned;
    }

    private String generateOtpCode() {
        int value = OTP_RANDOM.nextInt(1_000_000);
        return String.format("%06d", value);
    }
}
