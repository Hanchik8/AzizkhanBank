package com.bank.notification.messaging;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class AuthEventsConsumer {

    private static final Logger log = LoggerFactory.getLogger(AuthEventsConsumer.class);

    private final ObjectMapper objectMapper;

    public AuthEventsConsumer(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @KafkaListener(
        topics = "${app.kafka.topics.auth-events:auth.events.v1}",
        groupId = "${spring.kafka.consumer.group-id:notification-service}"
    )
    public void consume(String payload) {
        AuthEventPayload event = parsePayload(payload);
        if (event == null) {
            return;
        }

        if (!StringUtils.hasText(event.phoneNumber()) || !StringUtils.hasText(event.otpCode())) {
            log.warn("Received auth event with empty phoneNumber or otpCode: {}", payload);
            return;
        }

        log.info("Sending SMS to [{}]: Your code is [{}]", event.phoneNumber(), event.otpCode());
    }

    private AuthEventPayload parsePayload(String payload) {
        try {
            return objectMapper.readValue(payload, AuthEventPayload.class);
        } catch (JsonProcessingException exception) {
            log.warn("Failed to parse auth event payload: {}", payload, exception);
            return null;
        }
    }
}
