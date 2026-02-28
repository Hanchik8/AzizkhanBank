--liquibase formatted sql

--changeset platform:0001-core-ledger-schema splitStatements:true endDelimiter:;
CREATE TABLE accounts (
  id BIGINT PRIMARY KEY,
  customer_id VARCHAR(64) NOT NULL,
  currency CHAR(3) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  balance NUMERIC(19,4) NOT NULL DEFAULT 0.0000,
  version BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_accounts_balance_non_negative CHECK (balance >= 0),
  CONSTRAINT chk_accounts_version_non_negative CHECK (version >= 0),
  CONSTRAINT chk_accounts_currency_iso CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT chk_accounts_status CHECK (status IN ('ACTIVE', 'BLOCKED', 'CLOSED')),
  CONSTRAINT chk_accounts_timestamp_order CHECK (updated_at >= created_at)
);

CREATE INDEX idx_accounts_customer_id ON accounts (customer_id);
CREATE INDEX idx_accounts_status ON accounts (status);

CREATE TABLE transactions (
  transfer_id VARCHAR(64) PRIMARY KEY,
  from_account_id BIGINT NOT NULL,
  to_account_id BIGINT NOT NULL,
  amount NUMERIC(19,4) NOT NULL,
  currency CHAR(3) NOT NULL,
  status VARCHAR(16) NOT NULL,
  idempotency_key VARCHAR(128),
  requested_at TIMESTAMPTZ NOT NULL,
  committed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_transactions_from_account FOREIGN KEY (from_account_id)
    REFERENCES accounts (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_transactions_to_account FOREIGN KEY (to_account_id)
    REFERENCES accounts (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_transactions_positive_amount CHECK (amount > 0),
  CONSTRAINT chk_transactions_currency_iso CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT chk_transactions_status CHECK (status IN ('PENDING', 'COMMITTED', 'FAILED', 'REVERSED')),
  CONSTRAINT chk_transactions_distinct_accounts CHECK (from_account_id <> to_account_id),
  CONSTRAINT chk_transactions_idempotency_key_not_blank CHECK (
    idempotency_key IS NULL OR btrim(idempotency_key) <> ''
  ),
  CONSTRAINT chk_transactions_committed_timestamp CHECK (
    (status = 'COMMITTED' AND committed_at IS NOT NULL) OR
    (status <> 'COMMITTED' AND committed_at IS NULL)
  )
);

CREATE UNIQUE INDEX uq_transactions_idempotency_key
  ON transactions (idempotency_key)
  WHERE idempotency_key IS NOT NULL;
CREATE INDEX idx_transactions_requested_at ON transactions (requested_at);
CREATE INDEX idx_transactions_status ON transactions (status);

CREATE TABLE ledger_entries (
  id UUID PRIMARY KEY,
  transfer_id VARCHAR(64) NOT NULL,
  account_id BIGINT NOT NULL,
  entry_type VARCHAR(16) NOT NULL,
  amount NUMERIC(19,4) NOT NULL,
  currency CHAR(3) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ledger_entries_transaction FOREIGN KEY (transfer_id)
    REFERENCES transactions (transfer_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_ledger_entries_account FOREIGN KEY (account_id)
    REFERENCES accounts (id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_ledger_entries_entry_type CHECK (entry_type IN ('DEBIT', 'CREDIT')),
  CONSTRAINT chk_ledger_entries_positive_amount CHECK (amount > 0),
  CONSTRAINT chk_ledger_entries_currency_iso CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE UNIQUE INDEX uq_ledger_entries_transfer_account_type
  ON ledger_entries (transfer_id, account_id, entry_type);
CREATE INDEX idx_ledger_entries_account_created_at
  ON ledger_entries (account_id, created_at DESC);
CREATE INDEX idx_ledger_entries_transfer_id
  ON ledger_entries (transfer_id);

CREATE TABLE outbox_events (
  id UUID PRIMARY KEY,
  aggregate_type VARCHAR(64) NOT NULL,
  aggregate_id VARCHAR(128) NOT NULL,
  event_type VARCHAR(128) NOT NULL,
  payload TEXT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  published_at TIMESTAMPTZ,
  CONSTRAINT chk_outbox_status CHECK (status IN ('PENDING', 'PROCESSED')),
  CONSTRAINT chk_outbox_attempt_count_non_negative CHECK (attempt_count >= 0)
);

CREATE INDEX idx_outbox_status_created_at
  ON outbox_events (status, created_at ASC);

CREATE INDEX idx_outbox_aggregate
  ON outbox_events (aggregate_type, aggregate_id);

CREATE INDEX idx_outbox_unprocessed
  ON outbox_events (created_at ASC)
  WHERE status = 'PENDING';

--rollback DROP TABLE IF EXISTS outbox_events;
--rollback DROP TABLE IF EXISTS ledger_entries;
--rollback DROP TABLE IF EXISTS transactions;
--rollback DROP TABLE IF EXISTS accounts;
