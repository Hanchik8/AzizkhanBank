package com.bank.account.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import com.bank.account.domain.Account;
import com.bank.account.repository.AccountRepository;

@Service
public class InterestAccrualService {

    private static final Logger LOGGER = LoggerFactory.getLogger(InterestAccrualService.class);

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

    private static final int BATCH_SIZE = 100;

    @Scheduled(cron = "0 0 0 * * *")
    public void accrueDailyInterest() {
        LOGGER.info("Starting daily interest accrual");
        int processed = 0;
        int failed = 0;
        int page = 0;

        List<Account> batch;
        do {
            Pageable pageable = PageRequest.of(page, BATCH_SIZE);
            batch = accountRepository.findAllByStatus(ACTIVE_STATUS, pageable);

            for (Account account : batch) {
                if (SYSTEM_ACCOUNT_ID.equals(account.getId())) {
                    continue;
                }

                BigDecimal interestAmount = account.getBalance()
                    .multiply(ANNUAL_RATE)
                    .divide(DAYS_IN_YEAR, 8, RoundingMode.HALF_UP);

                if (interestAmount.signum() <= 0) {
                    continue;
                }

                try {
                    TransferCommand command = new TransferCommand(
                        SYSTEM_USER_ID,
                        UUID.randomUUID().toString(),
                        SYSTEM_ACCOUNT_ID,
                        account.getId(),
                        interestAmount,
                        account.getCurrency(),
                        Instant.now()
                    );

                    accountTransferService.transferInternal(command);
                    processed++;
                } catch (Exception ex) {
                    failed++;
                    LOGGER.error("Interest accrual failed for accountId={}: {}",
                        account.getId(), ex.getMessage());
                }
            }
            page++;
        } while (batch.size() == BATCH_SIZE);

        LOGGER.info("Daily interest accrual completed: processed={}, failed={}", processed, failed);
    }
}
