package com.bank.account.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.bank.account.domain.Account;

import jakarta.persistence.LockModeType;

public interface AccountRepository extends JpaRepository<Account, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from Account a where a.id = :id")
    Optional<Account> findByIdForUpdate(@Param("id") Long id);

    @Query("select a.clientId from Account a where a.id = :id")
    Optional<String> findCustomerIdById(@Param("id") Long id);

    @Query("select a from Account a where a.clientId = :clientId")
    List<Account> findAllByClientId(@Param("clientId") String clientId);

    @Query(value = "select * from accounts where status = :status", nativeQuery = true)
    List<Account> findAllByStatus(@Param("status") String status);

    @Modifying
    @Transactional
    @Query("UPDATE Account a SET a.status = 'FROZEN' WHERE a.clientId = :clientId")
    void freezeAccountsByClientId(@Param("clientId") String clientId);
}
