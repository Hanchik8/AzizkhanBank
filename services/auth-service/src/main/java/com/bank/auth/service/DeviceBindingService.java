package com.bank.auth.service;

import java.util.UUID;

import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class DeviceBindingService {

    private final JwtService jwtService;
    private final ClientDeviceService clientDeviceService;
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;
    private final String userRegisteredTopic;

    public DeviceBindingService(
        JwtService jwtService,
        ClientDeviceService clientDeviceService,
        KafkaTemplate<String, String> kafkaTemplate,
        ObjectMapper objectMapper,
        @Value("${app.kafka.topics.user-registered:user.registered.v1}") String userRegisteredTopic
    ) {
        this.jwtService = jwtService;
        this.clientDeviceService = clientDeviceService;
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
        this.userRegisteredTopic = userRegisteredTopic;
    }

    public JwtService.TokenPair bindDevice(String authorizationHeader, String deviceId, String publicKey) {
        UUID userId = jwtService.requireRegistrationUserId(authorizationHeader);
        clientDeviceService.registerDevice(userId.toString(), deviceId, publicKey);
        publishUserRegistered(userId);
        return jwtService.generateFinalTokenPair(userId, deviceId);
    }

    private void publishUserRegistered(UUID userId) {
        try {
            String payload = objectMapper.writeValueAsString(
                java.util.Map.of("userId", userId.toString(), "eventType", "USER_REGISTERED")
            );
            kafkaTemplate.send(userRegisteredTopic, userId.toString(), payload);
        } catch (Exception ex) {
            // Non-critical: account will be created on retry or manual provisioning
        }
    }
}
