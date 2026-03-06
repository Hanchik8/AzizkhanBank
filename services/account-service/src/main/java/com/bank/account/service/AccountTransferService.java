package com.bank.account.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.stereotype.Service;

import com.bank.account.config.RedisLockProperties;
import com.bank.account.repository.AccountRepository;

@Service
public class AccountTransferService {

    private static final Long SYSTEM_ACCOUNT_ID = 9999L;
    private static final String SYSTEM_USER_ID = "SYSTEM";

    private final AccountRepository accountRepository;
    private final TransferTransactionHelper txHelper;
    private final RedissonClient redissonClient;
    private final RedisLockProperties redisLockProperties;

    public AccountTransferService(
        AccountRepository accountRepository,
        TransferTransactionHelper txHelper,
        RedissonClient redissonClient,
        RedisLockProperties redisLockProperties
    ) {
        this.accountRepository = accountRepository;
        this.txHelper = txHelper;
        this.redissonClient = redissonClient;
        this.redisLockProperties = redisLockProperties;
    }

    public TransferResult transfer(TransferCommand command) {
        command.validate();
        if (!SYSTEM_USER_ID.equals(command.userId())) {
            verifySourceAccountOwnership(command);
        }

        List<RLock> locks = acquireAccountLocks(command.fromAccountId(), command.toAccountId(), SYSTEM_ACCOUNT_ID);
        try {
            return txHelper.executeTransfer(command);
        } finally {
            releaseLocks(locks);
        }
    }

    public TransferResult transferInternal(TransferCommand command) {
        command.validate();

        List<RLock> locks = acquireAccountLocks(command.fromAccountId(), command.toAccountId());
        try {
            return txHelper.executeInternalTransfer(command);
        } finally {
            releaseLocks(locks);
        }
    }

    private void verifySourceAccountOwnership(TransferCommand command) {
        String ownerId = accountRepository.findCustomerIdById(command.fromAccountId())
            .orElseThrow(() -> new IllegalArgumentException("Source account not found"));
        if (!ownerId.equals(command.userId())) {
            throw new org.springframework.security.access.AccessDeniedException(
                "Source account does not belong to authenticated user");
        }
    }

    private List<RLock> acquireAccountLocks(Long... accountIds) {
        List<Long> orderedIds = java.util.Arrays.stream(accountIds)
            .distinct()
            .sorted(Comparator.naturalOrder())
            .toList();

        List<RLock> acquired = new ArrayList<>(orderedIds.size());
        try {
            for (Long id : orderedIds) {
                RLock lock = redissonClient.getLock("account:lock:" + id);
                boolean locked = lock.tryLock(
                    redisLockProperties.getWaitTimeout().toMillis(),
                    redisLockProperties.getLeaseTimeout().toMillis(),
                    TimeUnit.MILLISECONDS
                );
                if (!locked) {
                    throw new IllegalStateException("Transfer temporarily unavailable, please try again");
                }
                acquired.add(lock);
            }
            return acquired;
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            releaseLocks(acquired);
            throw new IllegalStateException("Transfer temporarily unavailable, please try again");
        } catch (RuntimeException ex) {
            releaseLocks(acquired);
            throw ex;
        }
    }

    private void releaseLocks(List<RLock> locks) {
        for (int i = locks.size() - 1; i >= 0; i--) {
            try {
                if (locks.get(i).isHeldByCurrentThread()) {
                    locks.get(i).unlock();
                }
            } catch (RuntimeException ignored) {
            }
        }
    }
}
