-- Create products table in Hive
USE ecommerce;

DROP TABLE IF EXISTS products;

CREATE EXTERNAL TABLE products (
    product_id BIGINT,
    product_name STRING,
    category STRING,
    brand STRING,
    price DECIMAL(10,2),
    cost DECIMAL(10,2),
    description STRING,
    sku STRING,
    stock_quantity INT,
    weight DECIMAL(5,2),
    dimensions STRING,
    created_date DATE,
    updated_date DATE
)
COMMENT 'Product catalog table'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/products/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Load data into the table
LOAD DATA INPATH '/data/sample-data/products.csv' INTO TABLE products;