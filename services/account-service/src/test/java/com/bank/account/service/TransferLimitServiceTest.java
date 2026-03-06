package com.bank.account.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.math.BigDecimal;
import java.util.Collections;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.redisson.api.RScript;
import org.redisson.api.RedissonClient;

class TransferLimitServiceTest {

    private RedissonClient redissonClient;
    private RScript rScript;
    private TransferLimitService service;

    @BeforeEach
    void setUp() {
        redissonClient = mock(RedissonClient.class);
        rScript = mock(RScript.class);
        when(redissonClient.getScript(any())).thenReturn(rScript);
        service = new TransferLimitService(redissonClient);
    }

    @Test
    void shouldPassWhenUnderLimit() {
        when(rScript.eval(any(), anyString(), any(), any(), any())).thenReturn("5000");
        assertDoesNotThrow(() -> service.checkAndRecordDailyLimit("user1", new BigDecimal("5000")));
    }

    @Test
    void shouldThrowWhenOverLimit() {
        when(rScript.eval(any(), anyString(), any(), any(), any())).thenReturn("-1");
        assertThrows(LimitExceededException.class,
            () -> service.checkAndRecordDailyLimit("user1", new BigDecimal("200000")));
    }

    @Test
    void shouldSkipSystemUser() {
        assertDoesNotThrow(() -> service.checkAndRecordDailyLimit("SYSTEM", new BigDecimal("999999")));
        verifyNoInteractions(rScript);
    }

    @Test
    void shouldRejectNullUserId() {
        assertThrows(IllegalArgumentException.class,
            () -> service.checkAndRecordDailyLimit(null, BigDecimal.TEN));
    }

    @Test
    void shouldRejectNegativeAmount() {
        assertThrows(IllegalArgumentException.class,
            () -> service.checkAndRecordDailyLimit("user1", new BigDecimal("-1")));
    }
}
