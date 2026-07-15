-- Upgrade an existing MCS v1 database without dropping data.
ALTER TABLE merchants ADD COLUMN IF NOT EXISTS business_name VARCHAR(150);
UPDATE merchants SET business_name = name
WHERE business_name IS NULL OR BTRIM(business_name) = '';
ALTER TABLE merchants ALTER COLUMN business_name SET NOT NULL;

ALTER TABLE transactions ADD COLUMN IF NOT EXISTS initiated_at TIMESTAMP;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS authorized_at TIMESTAMP;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS settled_at TIMESTAMP;
UPDATE transactions SET initiated_at = COALESCE(initiated_at, created_at, NOW());
UPDATE transactions SET authorized_at = COALESCE(authorized_at, updated_at)
WHERE status IN ('AUTHORIZED', 'SETTLED');
UPDATE transactions SET settled_at = COALESCE(settled_at, updated_at)
WHERE status = 'SETTLED';
ALTER TABLE transactions ALTER COLUMN initiated_at SET NOT NULL;

-- Keep the database constraint aligned with the API validation options.
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_payment_method_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_payment_method_check
    CHECK (payment_method IN ('CARD', 'UPI', 'NETBANKING'));

ALTER TABLE settlements ADD COLUMN IF NOT EXISTS created_at TIMESTAMP;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP;
UPDATE settlements SET created_at = COALESCE(created_at, settled_at, NOW());
UPDATE settlements SET updated_at = COALESCE(updated_at, settled_at, created_at, NOW());
ALTER TABLE settlements ALTER COLUMN created_at SET NOT NULL;
ALTER TABLE settlements ALTER COLUMN updated_at SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uk_settlements_transaction_id'
    ) THEN
        ALTER TABLE settlements
            ADD CONSTRAINT uk_settlements_transaction_id UNIQUE (transaction_id);
    END IF;
END $$;
