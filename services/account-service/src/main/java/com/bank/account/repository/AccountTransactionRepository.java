package com.bank.account.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.bank.account.domain.AccountTransaction;

import jakarta.persistence.LockModeType;

public interface AccountTransactionRepository extends JpaRepository<AccountTransaction, String> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from AccountTransaction t where t.idempotencyKey = :idempotencyKey")
    Optional<AccountTransaction> findByIdempotencyKeyForUpdate(@Param("idempotencyKey") String idempotencyKey);
}
