package com.bank.account.config;

import java.util.HashMap;
import java.util.Map;

import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;
import org.springframework.kafka.support.serializer.JsonSerializer;
import org.springframework.util.StringUtils;

import com.bank.account.outbox.TransactionCompletedEvent;

@Configuration
@EnableConfigurationProperties(KafkaTopicsProperties.class)
public class KafkaProducerConfig {

    @Bean
    public ProducerFactory<String, TransactionCompletedEvent> producerFactory(
        @Value("${spring.kafka.bootstrap-servers:localhost:9092}") String bootstrapServers,
        @Value("${spring.kafka.producer.transaction-id-prefix:account-service-tx-}") String txPrefix,
        @Value("${spring.kafka.properties.security.protocol:PLAINTEXT}") String securityProtocol
    ) {
        Map<String, Object> config = new HashMap<>();
        config.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        config.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        config.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
        config.put(ProducerConfig.ACKS_CONFIG, "all");
        config.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        config.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 5);
        config.put("security.protocol", securityProtocol);

        DefaultKafkaProducerFactory<String, TransactionCompletedEvent> factory =
            new DefaultKafkaProducerFactory<>(config);

        factory.setTransactionIdPrefix(StringUtils.hasText(txPrefix) ? txPrefix : "account-service-tx-");

        return factory;
    }

    @Bean
    public KafkaTemplate<String, TransactionCompletedEvent> kafkaTemplate(
        ProducerFactory<String, TransactionCompletedEvent> producerFactory
    ) {
        return new KafkaTemplate<>(producerFactory);
    }
}
