package com.bank.account.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Objects;

import com.bank.account.service.TransferCommand;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "transactions")
public class AccountTransaction {

    @Id
    @Column(name = "transfer_id", nullable = false, length = 64)
    private String transferId;

    @Column(name = "from_account_id", nullable = false)
    private Long fromAccountId;

    @Column(name = "to_account_id", nullable = false)
    private Long toAccountId;

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    private String currency;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private TransactionStatus status;

    @Column(name = "idempotency_key", length = 128)
    private String idempotencyKey;

    @Column(name = "requested_at", nullable = false)
    private Instant requestedAt;

    @Column(name = "committed_at")
    private Instant committedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected AccountTransaction() {
    }

    private AccountTransaction(
        String transferId,
        Long fromAccountId,
        Long toAccountId,
        BigDecimal amount,
        String currency,
        String idempotencyKey,
        Instant requestedAt
    ) {
        this.transferId = transferId;
        this.fromAccountId = fromAccountId;
        this.toAccountId = toAccountId;
        this.amount = amount;
        this.currency = currency;
        this.idempotencyKey = idempotencyKey;
        this.requestedAt = requestedAt;
        this.status = TransactionStatus.COMMITTED;
        this.committedAt = Instant.now();
        this.createdAt = Instant.now();
    }

    public static AccountTransaction committed(String transferId, TransferCommand command) {
        return new AccountTransaction(
            transferId,
            command.fromAccountId(),
            command.toAccountId(),
            command.amount(),
            command.normalizedCurrency(),
            command.idempotencyKey(),
            command.requestedAt()
        );
    }

    public boolean matches(TransferCommand command) {
        return Objects.equals(fromAccountId, command.fromAccountId())
            && Objects.equals(toAccountId, command.toAccountId())
            && amount.compareTo(command.amount()) == 0
            && Objects.equals(currency, command.normalizedCurrency());
    }

    public String getTransferId() {
        return transferId;
    }

    public Long getFromAccountId() {
        return fromAccountId;
    }

    public Long getToAccountId() {
        return toAccountId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public TransactionStatus getStatus() {
        return status;
    }

    public String getIdempotencyKey() {
        return idempotencyKey;
    }

    public Instant getRequestedAt() {
        return requestedAt;
    }

    public Instant getCommittedAt() {
        return committedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
