-- Banking Metadata Database Initialization

CREATE DATABASE IF NOT EXISTS banking_metadata;
USE banking_metadata;

-- Airflow tables will be created automatically

-- Hive Metastore tables
CREATE TABLE IF NOT EXISTS SEQUENCE_TABLE (
    SEQUENCE_NAME VARCHAR(255) NOT NULL,
    NEXT_VAL BIGINT NOT NULL,
    PRIMARY KEY (SEQUENCE_NAME)
);

-- Insert initial sequence values
INSERT IGNORE INTO SEQUENCE_TABLE (SEQUENCE_NAME, NEXT_VAL) VALUES 
('org.apache.hadoop.hive.metastore.model.MDatabase', 1),
('org.apache.hadoop.hive.metastore.model.MTable', 1),
('org.apache.hadoop.hive.metastore.model.MPartition', 1);

-- Banking specific tables
CREATE TABLE IF NOT EXISTS banking_customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS banking_accounts (
    account_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    account_type VARCHAR(20),
    balance DECIMAL(15,2),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES banking_customers(customer_id)
);

CREATE TABLE IF NOT EXISTS banking_transactions (
    transaction_id VARCHAR(30) PRIMARY KEY,
    from_account VARCHAR(20),
    to_account VARCHAR(20),
    amount DECIMAL(15,2),
    transaction_type VARCHAR(20),
    status VARCHAR(20),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT IGNORE INTO banking_customers VALUES 
('CUST001', 'Nguyen', 'Van A', 'nva@email.com', '0901234567', 'Ha Noi', NOW()),
('CUST002', 'Tran', 'Thi B', 'ttb@email.com', '0902345678', 'Ho Chi Minh', NOW()),
('CUST003', 'Le', 'Van C', 'lvc@email.com', '0903456789', 'Da Nang', NOW());

INSERT IGNORE INTO banking_accounts VALUES 
('ACC001', 'CUST001', 'CHECKING', 50000000.00, 'ACTIVE', NOW()),
('ACC002', 'CUST002', 'SAVINGS', 75000000.00, 'ACTIVE', NOW()),
('ACC003', 'CUST003', 'CHECKING', 30000000.00, 'ACTIVE', NOW());

INSERT IGNORE INTO banking_transactions VALUES 
('TXN001', 'ACC001', 'ACC002', 1000000.00, 'TRANSFER', 'COMPLETED', NOW()),
('TXN002', 'ACC002', 'ACC003', 500000.00, 'TRANSFER', 'COMPLETED', NOW()),
('TXN003', 'ACC001', 'ACC003', 2000000.00, 'TRANSFER', 'PENDING', NOW());

