-- Create orders table in Hive
USE ecommerce;

DROP TABLE IF EXISTS orders;

CREATE EXTERNAL TABLE orders (
    order_id BIGINT,
    customer_id BIGINT,
    order_date TIMESTAMP,
    order_status STRING,
    total_amount DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    shipping_amount DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    payment_method STRING,
    shipping_address STRING,
    billing_address STRING,
    order_notes STRING
)
COMMENT 'Order transactions table'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/orders/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Load data into the table
LOAD DATA INPATH '/data/sample-data/orders.csv' INTO TABLE orders;