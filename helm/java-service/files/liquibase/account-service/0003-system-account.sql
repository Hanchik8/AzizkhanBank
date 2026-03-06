--liquibase formatted sql

--changeset platform:0003-system-account splitStatements:true endDelimiter:;
INSERT INTO accounts (id, customer_id, currency, balance, status, version, created_at, updated_at)
VALUES (9999, 'SYSTEM', 'KGS', 0.0000, 'ACTIVE', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;

--rollback DELETE FROM accounts WHERE id = 9999;
