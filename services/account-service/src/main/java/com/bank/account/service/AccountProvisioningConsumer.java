package com.bank.account.service;

import java.math.BigDecimal;
import java.time.Instant;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.bank.account.domain.Account;
import com.bank.account.repository.AccountRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@Component
public class AccountProvisioningConsumer {

    private static final Logger LOGGER = LoggerFactory.getLogger(AccountProvisioningConsumer.class);
    private static final String DEFAULT_CURRENCY = "KGS";

    private final AccountRepository accountRepository;
    private final ObjectMapper objectMapper;

    public AccountProvisioningConsumer(AccountRepository accountRepository, ObjectMapper objectMapper) {
        this.accountRepository = accountRepository;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(
        topics = "${banking.kafka.topics.user-registered:user.registered.v1}",
        groupId = "${spring.application.name:account-service}-user-provisioning"
    )
    @Transactional
    public void onUserRegistered(String message) {
        String userId = extractUserId(message);
        if (userId == null || userId.isBlank()) {
            LOGGER.warn("Received user-registered event without userId");
            return;
        }

        if (!accountRepository.findAllByClientId(userId).isEmpty()) {
            LOGGER.debug("Accounts already exist for userId={}, skipping provisioning", userId);
            return;
        }

        Account account = Account.createNew(userId, DEFAULT_CURRENCY);
        accountRepository.save(account);
        LOGGER.info("Provisioned default {} account for userId={}", DEFAULT_CURRENCY, userId);
    }

    private String extractUserId(String message) {
        try {
            JsonNode node = objectMapper.readTree(message);
            JsonNode userIdNode = node.get("userId");
            return userIdNode == null || userIdNode.isNull() ? null : userIdNode.asText();
        } catch (Exception ex) {
            LOGGER.warn("Failed to parse user-registered event: {}", message, ex);
            return null;
        }
    }
}
