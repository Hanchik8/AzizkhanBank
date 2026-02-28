package com.bank.account.config;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "banking.redis.lock")
public class RedisLockProperties {

    private String host;
    private int port = 6379;
    private boolean ssl = true;
    private String password;
    private Duration waitTimeout = Duration.ofSeconds(5);
    private Duration leaseTimeout = Duration.ofSeconds(15);

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public int getPort() {
        return port;
    }

    public void setPort(int port) {
        this.port = port;
    }

    public boolean isSsl() {
        return ssl;
    }

    public void setSsl(boolean ssl) {
        this.ssl = ssl;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public Duration getWaitTimeout() {
        return waitTimeout;
    }

    public void setWaitTimeout(Duration waitTimeout) {
        this.waitTimeout = waitTimeout;
    }

    public Duration getLeaseTimeout() {
        return leaseTimeout;
    }

    public void setLeaseTimeout(Duration leaseTimeout) {
        this.leaseTimeout = leaseTimeout;
    }
}
