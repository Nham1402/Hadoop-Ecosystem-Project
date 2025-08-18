-- Sample E-commerce Data for Demo

-- Create tables
CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    city VARCHAR(50),
    state VARCHAR(50),
    registration_date DATE
);

CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    brand VARCHAR(50),
    price DECIMAL(10,2),
    stock_quantity INTEGER
);

CREATE TABLE IF NOT EXISTS orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    order_date TIMESTAMP,
    total_amount DECIMAL(10,2),
    order_status VARCHAR(20)
);

-- Insert sample data
INSERT INTO customers (first_name, last_name, email, phone, city, state, registration_date) VALUES
('John', 'Doe', 'john.doe@email.com', '+1-555-0101', 'New York', 'NY', '2023-01-15'),
('Jane', 'Smith', 'jane.smith@email.com', '+1-555-0102', 'Los Angeles', 'CA', '2023-02-20'),
('Mike', 'Johnson', 'mike.johnson@email.com', '+1-555-0103', 'Chicago', 'IL', '2023-03-10'),
('Sarah', 'Williams', 'sarah.williams@email.com', '+1-555-0104', 'Houston', 'TX', '2023-04-05'),
('David', 'Brown', 'david.brown@email.com', '+1-555-0105', 'Phoenix', 'AZ', '2023-05-12');

INSERT INTO products (product_name, category, brand, price, stock_quantity) VALUES
('iPhone 14 Pro', 'Electronics', 'Apple', 999.99, 50),
('Samsung Galaxy S23', 'Electronics', 'Samsung', 799.99, 75),
('MacBook Air M2', 'Electronics', 'Apple', 1199.99, 30),
('Nike Air Max 270', 'Footwear', 'Nike', 130.00, 100),
('Adidas Ultraboost 22', 'Footwear', 'Adidas', 180.00, 80);

INSERT INTO orders (customer_id, order_date, total_amount, order_status) VALUES
(1, '2024-01-01 10:30:00', 1059.99, 'completed'),
(2, '2024-01-02 14:15:00', 829.99, 'completed'),
(3, '2024-01-03 09:45:00', 1319.98, 'shipped'),
(4, '2024-01-04 16:20:00', 189.99, 'processing'),
(5, '2024-01-05 11:10:00', 409.98, 'completed');
