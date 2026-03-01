package com.bank.account.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import com.bank.account.repository.AccountRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@Component
public class FraudAlertConsumer {

    private static final Logger LOGGER = LoggerFactory.getLogger(FraudAlertConsumer.class);

    private final AccountRepository accountRepository;
    private final ObjectMapper objectMapper;

    public FraudAlertConsumer(
        AccountRepository accountRepository,
        ObjectMapper objectMapper
    ) {
        this.accountRepository = accountRepository;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(
        topics = "${banking.kafka.topics.fraud-alerts:fraud.alerts}",
        groupId = "${spring.application.name:account-service}-fraud-alerts"
    )
    public void onFraudAlert(String message) {
        String userId = extractUserId(message);
        if (userId == null || userId.isBlank()) {
            LOGGER.warn("Received fraud alert without userId: {}", message);
            return;
        }

        accountRepository.freezeAccountsByClientId(userId);
        LOGGER.info("Frozen accounts for clientId={} due to fraud alert", userId);
    }

    private String extractUserId(String message) {
        if (message == null || message.isBlank()) {
            return null;
        }

        try {
            JsonNode node = objectMapper.readTree(message);
            JsonNode userIdNode = node.get("userId");
            return userIdNode == null || userIdNode.isNull() ? null : userIdNode.asText();
        } catch (Exception ex) {
            LOGGER.warn("Failed to parse fraud alert payload: {}", message, ex);
            return null;
        }
    }
}
