package com.bank.account.outbox;

import java.util.List;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.bank.account.config.KafkaTopicsProperties;
import com.fasterxml.jackson.databind.ObjectMapper;

@Component
public class OutboxKafkaPublisher {

    private static final Logger LOGGER = LoggerFactory.getLogger(OutboxKafkaPublisher.class);

    private final OutboxEventRepository outboxEventRepository;
    private final KafkaTemplate<String, TransactionCompletedEvent> kafkaTemplate;
    private final KafkaTopicsProperties kafkaTopicsProperties;
    private final ObjectMapper objectMapper;
    private final TransactionTemplate transactionTemplate;
    private final int batchSize;
    private final long publishTimeoutSeconds;

    public OutboxKafkaPublisher(
        OutboxEventRepository outboxEventRepository,
        KafkaTemplate<String, TransactionCompletedEvent> kafkaTemplate,
        KafkaTopicsProperties kafkaTopicsProperties,
        ObjectMapper objectMapper,
        PlatformTransactionManager transactionManager,
        @Value("${banking.outbox.batch-size:100}") int batchSize,
        @Value("${banking.outbox.publish-timeout-seconds:10}") long publishTimeoutSeconds
    ) {
        this.outboxEventRepository = outboxEventRepository;
        this.kafkaTemplate = kafkaTemplate;
        this.kafkaTopicsProperties = kafkaTopicsProperties;
        this.objectMapper = objectMapper;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.batchSize = batchSize;
        this.publishTimeoutSeconds = publishTimeoutSeconds;
    }

    @Scheduled(
        fixedDelayString = "${banking.outbox.poll-interval:2000}",
        initialDelayString = "${banking.outbox.initial-delay:5000}"
    )
    public void publishPendingEvents() {
        int processed;
        do {
            Integer batchResult = transactionTemplate.execute(ignored -> publishOneBatchInCurrentTx());
            processed = batchResult == null ? 0 : batchResult;
        } while (processed == batchSize);
    }

    private int publishOneBatchInCurrentTx() {
        List<OutboxEvent> pendingEvents = outboxEventRepository.lockPendingBatch(batchSize);

        for (OutboxEvent outboxEvent : pendingEvents) {
            publishSingle(outboxEvent);
        }

        return pendingEvents.size();
    }

    private void publishSingle(OutboxEvent outboxEvent) {
        try {
            TransactionCompletedEvent eventPayload = objectMapper.readValue(
                outboxEvent.getPayload(),
                TransactionCompletedEvent.class
            );

            kafkaTemplate
                .send(kafkaTopicsProperties.getAccountEvents(), eventPayload.transferId(), eventPayload)
                .get(publishTimeoutSeconds, TimeUnit.SECONDS);

            outboxEvent.markProcessed();
        } catch (Exception ex) {
            outboxEvent.registerPublishFailure(ex.getMessage());
            LOGGER.error("Outbox publish failed for eventId={} transferId={}",
                outboxEvent.getId(),
                outboxEvent.getAggregateId(),
                ex
            );
        }
    }
}
