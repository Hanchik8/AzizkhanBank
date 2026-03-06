package com.bank.account.domain;

import static org.junit.jupiter.api.Assertions.*;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

class AccountTest {

    @Test
    void debitShouldReduceBalance() {
        Account account = Account.createNew("user1", "KGS");
        account.credit(new BigDecimal("1000.0000"));
        account.debit(new BigDecimal("300.0000"));
        assertEquals(new BigDecimal("700.0000"), account.getBalance());
    }

    @Test
    void debitShouldThrowOnInsufficientFunds() {
        Account account = Account.createNew("user1", "KGS");
        account.credit(new BigDecimal("100.0000"));
        assertThrows(IllegalStateException.class,
            () -> account.debit(new BigDecimal("200.0000")));
    }

    @Test
    void creditShouldMaintainScale() {
        Account account = Account.createNew("user1", "KGS");
        account.credit(new BigDecimal("0.00013698"));
        assertEquals(4, account.getBalance().scale());
    }

    @Test
    void shouldDetectFrozen() {
        Account account = Account.createNew("user1", "KGS");
        assertFalse(account.isFrozen());
    }

    @Test
    void shouldEnforceCurrency() {
        Account account = Account.createNew("user1", "KGS");
        assertThrows(IllegalArgumentException.class, () -> account.ensureCurrency("USD"));
        assertDoesNotThrow(() -> account.ensureCurrency("KGS"));
    }
}
