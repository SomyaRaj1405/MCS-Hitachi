-- MCS Database Schema
-- Merchant Checkout System | Hitachi Payments

CREATE TABLE merchants (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    business_name VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(15),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(15),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bills (
    id SERIAL PRIMARY KEY,
    merchant_id INT NOT NULL,
    customer_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    description VARCHAR(255),
    status VARCHAR(20) DEFAULT 'PENDING' 
        CHECK (status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
    payment_method VARCHAR(50),
    refund_reason VARCHAR(255),
    refunded_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_merchant FOREIGN KEY (merchant_id) 
        REFERENCES merchants(id) ON DELETE RESTRICT,
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) 
        REFERENCES customers(id) ON DELETE RESTRICT
);

CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL,
    payment_method VARCHAR(10) NOT NULL
        CHECK (payment_method IN ('CARD', 'UPI', 'NETBANKING')),
    status VARCHAR(20) DEFAULT 'INITIATED'
        CHECK (status IN ('INITIATED', 'AUTHORIZED', 'SETTLED', 'FAILED')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    initiated_at TIMESTAMP DEFAULT NOW() NOT NULL,
    authorized_at TIMESTAMP,
    settled_at TIMESTAMP,
    CONSTRAINT fk_bill FOREIGN KEY (bill_id)
        REFERENCES bills(id) ON DELETE RESTRICT
);

CREATE TABLE settlements (
    id SERIAL PRIMARY KEY,
    transaction_id INT UNIQUE NOT NULL,
    settled_amount DECIMAL(10,2) NOT NULL,
    reference_number VARCHAR(100) UNIQUE NOT NULL,
    settled_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_transaction FOREIGN KEY (transaction_id)
        REFERENCES transactions(id) ON DELETE RESTRICT
);
