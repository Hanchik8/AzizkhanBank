package com.bank.account.config;

import org.redisson.Redisson;
import org.redisson.api.RedissonClient;
import org.redisson.config.Config;
import org.redisson.config.SingleServerConfig;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

@Configuration
@EnableConfigurationProperties(RedisLockProperties.class)
public class RedissonConfig {

    @Bean(destroyMethod = "shutdown")
    public RedissonClient redissonClient(RedisLockProperties properties) {
        String scheme = properties.isSsl() ? "rediss://" : "redis://";

        Config config = new Config();
        SingleServerConfig serverConfig = config.useSingleServer()
            .setAddress(scheme + properties.getHost() + ":" + properties.getPort())
            .setConnectionMinimumIdleSize(2)
            .setConnectionPoolSize(16)
            .setTimeout(3000)
            .setConnectTimeout(3000)
            .setKeepAlive(true)
            .setTcpNoDelay(true);

        if (StringUtils.hasText(properties.getPassword())) {
            serverConfig.setPassword(properties.getPassword());
        }

        return Redisson.create(config);
    }
}
