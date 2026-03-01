package com.bank.fraud.config;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Locale;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.Grouped;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.KTable;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.TimeWindows;
import org.apache.kafka.streams.kstream.Windowed;
import org.apache.kafka.streams.KeyValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.kafka.support.serializer.JsonSerde;

import com.bank.fraud.model.FraudAlert;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@Configuration
@EnableKafkaStreams
public class FraudTopologyConfig {

    private static final Logger LOGGER = LoggerFactory.getLogger(FraudTopologyConfig.class);

    private static final BigDecimal NIGHT_WINDOW_LIMIT = new BigDecimal("50000");

    private final ObjectMapper objectMapper;
    private final String outboxTopic;
    private final String fraudAlertsTopic;

    public FraudTopologyConfig(
        ObjectMapper objectMapper,
        @Value("${app.kafka.topics.outbox-events:account.events.v1}") String outboxTopic,
        @Value("${app.kafka.topics.fraud-alerts:fraud.alerts}") String fraudAlertsTopic
    ) {
        this.objectMapper = objectMapper;
        this.outboxTopic = outboxTopic;
        this.fraudAlertsTopic = fraudAlertsTopic;
    }

    @Bean
    public KStream<String, String> fraudDetectionTopology(StreamsBuilder streamsBuilder) {
        KStream<String, String> source = streamsBuilder.stream(
            outboxTopic,
            Consumed.with(Serdes.String(), Serdes.String())
        );

        KStream<String, SuspiciousTransfer> suspiciousNightTransfers = source
            .flatMap((key, value) -> parseTransferCreatedEvent(value))
            .filter((userId, transfer) -> isNightTransfer(transfer.timestamp()));

        KTable<Windowed<String>, Double> hourlyNightSumByUser = suspiciousNightTransfers
            .mapValues(transfer -> transfer.amount().doubleValue())
            .groupByKey(Grouped.with(Serdes.String(), Serdes.Double()))
            .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofHours(1)))
            .reduce(Double::sum, Materialized.with(Serdes.String(), Serdes.Double()));

        hourlyNightSumByUser
            .toStream()
            .filter((windowedUserId, totalAmount) -> totalAmount != null && totalAmount > NIGHT_WINDOW_LIMIT.doubleValue())
            .map((windowedUserId, totalAmount) -> {
                String userId = windowedUserId.key();
                FraudAlert alert = new FraudAlert(
                    userId,
                    "Night transfers exceeded 50000 in a 1-hour window"
                );
                return KeyValue.pair(userId, alert);
            })
            .to(fraudAlertsTopic, Produced.with(Serdes.String(), new JsonSerde<>(FraudAlert.class)));

        return source;
    }

    private List<KeyValue<String, SuspiciousTransfer>> parseTransferCreatedEvent(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            return List.of();
        }

        try {
            JsonNode node = objectMapper.readTree(rawValue);
            if (!isTransferCreatedEvent(node)) {
                return List.of();
            }

            String userId = firstText(node, "userId", "clientId", "customerId");
            if (userId == null || userId.isBlank()) {
                return List.of();
            }

            BigDecimal amount = decimalValue(node, "amount");
            Instant timestamp = instantValue(node, "timestamp", "createdAt", "committedAt", "requestedAt");
            if (amount == null || amount.signum() <= 0 || timestamp == null) {
                return List.of();
            }

            return List.of(KeyValue.pair(userId, new SuspiciousTransfer(userId, amount, timestamp)));
        } catch (Exception ex) {
            LOGGER.debug("Skipping unparsable event: {}", rawValue, ex);
            return List.of();
        }
    }

    private static boolean isTransferCreatedEvent(JsonNode node) {
        String type = firstText(node, "type", "eventType", "event_type");
        if (type == null || type.isBlank()) {
            // If producer omits type, treat event as transfer-created candidate from outbox topic.
            return true;
        }

        String normalized = type.toUpperCase(Locale.ROOT);
        return normalized.equals("TRANSFER_CREATED")
            || normalized.equals("TRANSFER_CREATE")
            || normalized.equals("TRANSACTION_CREATED")
            || normalized.equals("TRANSACTION_COMPLETED");
    }

    private static boolean isNightTransfer(Instant timestamp) {
        int hour = timestamp.atZone(ZoneOffset.UTC).getHour();
        return hour >= 0 && hour < 6;
    }

    private static String firstText(JsonNode node, String... fieldNames) {
        for (String fieldName : fieldNames) {
            JsonNode value = node.get(fieldName);
            if (value != null && !value.isNull()) {
                String text = value.asText(null);
                if (text != null && !text.isBlank()) {
                    return text;
                }
            }
        }
        return null;
    }

    private static BigDecimal decimalValue(JsonNode node, String fieldName) {
        JsonNode value = node.get(fieldName);
        if (value == null || value.isNull()) {
            return null;
        }

        try {
            return value.isNumber() ? value.decimalValue() : new BigDecimal(value.asText());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private static Instant instantValue(JsonNode node, String... fieldNames) {
        for (String fieldName : fieldNames) {
            JsonNode value = node.get(fieldName);
            if (value == null || value.isNull()) {
                continue;
            }
            try {
                if (value.isNumber()) {
                    return Instant.ofEpochMilli(value.asLong());
                }
                return Instant.parse(value.asText());
            } catch (Exception ignored) {
                // Try next timestamp field.
            }
        }
        return null;
    }

    private record SuspiciousTransfer(
        String userId,
        BigDecimal amount,
        Instant timestamp
    ) {
    }
}
