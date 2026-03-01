package com.bank.account.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.UUID;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import com.bank.account.domain.Account;
import com.bank.account.repository.AccountRepository;

@Service
public class InterestAccrualService {

    private static final String ACTIVE_STATUS = "ACTIVE";
    private static final Long SYSTEM_ACCOUNT_ID = 9999L;
    private static final String SYSTEM_USER_ID = "SYSTEM";
    private static final BigDecimal ANNUAL_RATE = new BigDecimal("0.05");
    private static final BigDecimal DAYS_IN_YEAR = new BigDecimal("365");

    private final AccountRepository accountRepository;
    private final AccountTransferService accountTransferService;

    public InterestAccrualService(
        AccountRepository accountRepository,
        AccountTransferService accountTransferService
    ) {
        this.accountRepository = accountRepository;
        this.accountTransferService = accountTransferService;
    }

    @Scheduled(cron = "0 0 0 * * *")
    public void accrueDailyInterest() {
        for (Account account : accountRepository.findAllByStatus(ACTIVE_STATUS)) {
            if (SYSTEM_ACCOUNT_ID.equals(account.getId())) {
                continue;
            }

            BigDecimal interestAmount = account.getBalance()
                .multiply(ANNUAL_RATE)
                .divide(DAYS_IN_YEAR, 8, RoundingMode.HALF_UP);

            if (interestAmount.signum() <= 0) {
                continue;
            }

            TransferCommand command = new TransferCommand(
                SYSTEM_USER_ID,
                UUID.randomUUID().toString(),
                SYSTEM_ACCOUNT_ID,
                account.getId(),
                interestAmount,
                account.getCurrency(),
                Instant.now()
            );

            accountTransferService.transfer(command);
        }
    }
}
