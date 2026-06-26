-- Seed merchants
INSERT INTO merchants (name, email, password_hash, phone) VALUES
('Sharma Electronics', 'sharma@electronics.com', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '9876543210'),
('Patel Traders', 'patel@traders.com', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '9823456789');

-- Seed customers
INSERT INTO customers (name, email, password_hash, phone) VALUES
('Rahul Verma', 'rahul@gmail.com', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '9811223344'),
('Priya Singh', 'priya@gmail.com', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '9833445566'),
('Amit Kumar', 'amit@gmail.com', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '9844556677'),
('Sneha Joshi', 'sneha@gmail.com', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '9855667788'),
('Rohit Sharma', 'rohit@gmail.com', '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '9866778899');

-- Seed bills
INSERT INTO bills (merchant_id, customer_id, amount, description, status) VALUES
(1, 1, 5000.00, 'Laptop repair service', 'PAID'),
(1, 2, 2500.00, 'Mobile screen replacement', 'PENDING'),
(1, 3, 8999.00, 'Smart TV purchase', 'PAID'),
(1, 4, 1500.00, 'Keyboard and mouse', 'FAILED'),
(2, 1, 3200.00, 'Wholesale grocery order', 'PAID'),
(2, 2, 750.00, 'Stationery supplies', 'PENDING'),
(2, 3, 12000.00, 'Bulk clothing order', 'PAID'),
(2, 5, 4500.00, 'Electronics accessories', 'PENDING');

-- Seed transactions
INSERT INTO transactions (bill_id, payment_method, status) VALUES
(1, 'CARD', 'SETTLED'),
(3, 'UPI', 'SETTLED'),
(4, 'CARD', 'FAILED'),
(5, 'UPI', 'SETTLED'),
(7, 'CARD', 'SETTLED');

-- Seed settlements
INSERT INTO settlements (transaction_id, settled_amount, reference_number) VALUES
(1, 5000.00, 'REF-MCS-001-2025'),
(2, 8999.00, 'REF-MCS-002-2025'),
(3, 3200.00, 'REF-MCS-003-2025'),
(4, 12000.00, 'REF-MCS-004-2025');