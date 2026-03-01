INSERT INTO accounts (id, client_id, currency, balance, status, created_at, updated_at)
VALUES (9999, 'SYSTEM', 'RUB', 0.00, 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT DO NOTHING;
