package com.bank.account.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "banking.kafka.topics")
public class KafkaTopicsProperties {

    private String accountEvents = "account.events.v1";

    public String getAccountEvents() {
        return accountEvents;
    }

    public void setAccountEvents(String accountEvents) {
        this.accountEvents = accountEvents;
    }
}
