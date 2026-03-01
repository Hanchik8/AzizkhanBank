package com.bank.account.service;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Collections;

import org.redisson.api.RScript;
import org.redisson.api.RedissonClient;
import org.redisson.client.codec.StringCodec;
import org.springframework.stereotype.Service;

@Service
public class TransferLimitService {

    private static final BigDecimal DAILY_LIMIT = new BigDecimal("100000");
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ISO_LOCAL_DATE;
    private static final String LIMIT_KEY_PREFIX = "limit:daily:";

    private final RedissonClient redissonClient;

    public TransferLimitService(RedissonClient redissonClient) {
        this.redissonClient = redissonClient;
    }

    public void checkAndRecordDailyLimit(String userId, BigDecimal amount) {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("userId is required");
        }
        if (amount == null || amount.signum() <= 0) {
            throw new IllegalArgumentException("amount must be positive");
        }

        ZonedDateTime now = ZonedDateTime.now(ZoneOffset.UTC);
        String key = buildDailyKey(userId, now);
        long ttlSeconds = ttlUntilEndOfDaySeconds(now);

        RScript script = redissonClient.getScript(StringCodec.INSTANCE);
        Object result = script.eval(
            RScript.Mode.READ_WRITE,
            """
            local key = KEYS[1]
            local increment = tonumber(ARGV[1])
            local ttl = tonumber(ARGV[2])
            local limit = tonumber(ARGV[3])
            local current = tonumber(redis.call('GET', key) or '0')
            local updated = current + increment
            if updated > limit then
              return -1
            end
            redis.call('SET', key, tostring(updated), 'EX', ttl)
            return updated
            """,
            RScript.ReturnType.VALUE,
            Collections.singletonList((Object) key),
            amount.toPlainString(),
            Long.toString(ttlSeconds),
            DAILY_LIMIT.toPlainString()
        );

        if (result == null) {
            throw new IllegalStateException("Failed to record daily transfer limit");
        }

        double updatedValue;
        if (result instanceof Number number) {
            updatedValue = number.doubleValue();
        } else {
            updatedValue = Double.parseDouble(result.toString());
        }

        if (updatedValue < 0) {
            throw new LimitExceededException(
                "Daily transfer limit exceeded. Max allowed amount is " + DAILY_LIMIT
            );
        }
    }

    private static String buildDailyKey(String userId, ZonedDateTime nowUtc) {
        return LIMIT_KEY_PREFIX + userId + ":" + nowUtc.toLocalDate().format(DATE_FORMAT);
    }

    private static long ttlUntilEndOfDaySeconds(ZonedDateTime nowUtc) {
        ZonedDateTime nextMidnight = nowUtc.toLocalDate().plusDays(1).atStartOfDay(ZoneOffset.UTC);
        long ttl = Duration.between(nowUtc, nextMidnight).getSeconds();
        return Math.max(ttl, 1);
    }
}
