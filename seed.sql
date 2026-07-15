-- Seed merchants
-- Demo password for every seeded account: McsDemo@123
INSERT INTO merchants (name, email, business_name, password_hash, phone) VALUES
('Sharma', 'sharma@electronics.com', 'Sharma Electronics', '$2a$10$lDzddzqXCEPfdMqDTdT16uXAVBTiXCpYDrPKsMcMyxeIxijaCdLKy', '9876543210'),
('Patel', 'patel@traders.com', 'Patel Traders', '$2a$10$lDzddzqXCEPfdMqDTdT16uXAVBTiXCpYDrPKsMcMyxeIxijaCdLKy', '9823456789');

-- Seed customers
INSERT INTO customers (name, email, password_hash, phone) VALUES
('Rahul Verma', 'rahul@gmail.com', '$2a$10$lDzddzqXCEPfdMqDTdT16uXAVBTiXCpYDrPKsMcMyxeIxijaCdLKy', '9811223344'),
('Priya Singh', 'priya@gmail.com', '$2a$10$lDzddzqXCEPfdMqDTdT16uXAVBTiXCpYDrPKsMcMyxeIxijaCdLKy', '9833445566'),
('Amit Kumar', 'amit@gmail.com', '$2a$10$lDzddzqXCEPfdMqDTdT16uXAVBTiXCpYDrPKsMcMyxeIxijaCdLKy', '9844556677'),
('Sneha Joshi', 'sneha@gmail.com', '$2a$10$lDzddzqXCEPfdMqDTdT16uXAVBTiXCpYDrPKsMcMyxeIxijaCdLKy', '9855667788'),
('Rohit Sharma', 'rohit@gmail.com', '$2a$10$lDzddzqXCEPfdMqDTdT16uXAVBTiXCpYDrPKsMcMyxeIxijaCdLKy', '9866778899');

-- Seed bills
INSERT INTO bills (merchant_id, customer_id, amount, description, status, payment_method) VALUES
(1, 1, 5000.00, 'Laptop repair service', 'PAID', 'CARD'),
(1, 2, 2500.00, 'Mobile screen replacement', 'PENDING', NULL),
(1, 3, 8999.00, 'Smart TV purchase', 'PAID', 'UPI'),
(1, 4, 1500.00, 'Keyboard and mouse', 'PENDING', NULL),
(2, 1, 3200.00, 'Wholesale grocery order', 'PAID', 'UPI'),
(2, 2, 750.00, 'Stationery supplies', 'PENDING', NULL),
(2, 3, 12000.00, 'Bulk clothing order', 'PAID', 'CARD'),
(2, 5, 4500.00, 'Electronics accessories', 'PENDING', NULL);

-- Seed transactions
INSERT INTO transactions (bill_id, payment_method, status, initiated_at, authorized_at, settled_at) VALUES
(1, 'CARD', 'SETTLED', NOW(), NOW(), NOW()),
(3, 'UPI', 'SETTLED', NOW(), NOW(), NOW()),
(4, 'CARD', 'FAILED', NOW(), NULL, NULL),
(5, 'UPI', 'SETTLED', NOW(), NOW(), NOW()),
(7, 'CARD', 'SETTLED', NOW(), NOW(), NOW());

-- Seed settlements
INSERT INTO settlements (transaction_id, settled_amount, reference_number) VALUES
(1, 5000.00, 'REF-MCS-001-2025'),
(2, 8999.00, 'REF-MCS-002-2025'),
(4, 3200.00, 'REF-MCS-003-2025'),
(5, 12000.00, 'REF-MCS-004-2025');
