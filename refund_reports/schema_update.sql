-- Run this against the MCS PostgreSQL database.
ALTER TABLE bills ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50);
ALTER TABLE bills ADD COLUMN IF NOT EXISTS refund_reason VARCHAR(255);
ALTER TABLE bills ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMP;

-- The original schema constraint rejects REFUNDED, so replace it.
ALTER TABLE bills DROP CONSTRAINT IF EXISTS bills_status_check;
ALTER TABLE bills ADD CONSTRAINT bills_status_check
    CHECK (status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED'));

-- Requested backfill for historical bills.
UPDATE bills SET payment_method = 'UPI' WHERE payment_method IS NULL;
