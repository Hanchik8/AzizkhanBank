package com.bank.auth.messaging;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class AuthEventPublisher {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;
    private final String authEventsTopic;

    public AuthEventPublisher(
        KafkaTemplate<String, String> kafkaTemplate,
        ObjectMapper objectMapper,
        @Value("${app.kafka.topics.auth-events:auth.events.v1}") String authEventsTopic
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
        this.authEventsTopic = authEventsTopic;
    }

    public void publishOtp(String phoneNumber, String otpCode) {
        AuthEventPayload event = new AuthEventPayload(phoneNumber, otpCode);
        try {
            String payload = objectMapper.writeValueAsString(event);
            kafkaTemplate.send(authEventsTopic, phoneNumber, payload);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Failed to serialize auth event payload", exception);
        }
    }
}
