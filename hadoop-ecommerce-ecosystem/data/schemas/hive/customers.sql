-- Create customers table in Hive
CREATE DATABASE IF NOT EXISTS ecommerce;
USE ecommerce;

DROP TABLE IF EXISTS customers;

CREATE EXTERNAL TABLE customers (
    customer_id BIGINT,
    first_name STRING,
    last_name STRING,
    email STRING,
    phone STRING,
    address STRING,
    city STRING,
    state STRING,
    zip_code STRING,
    country STRING,
    registration_date DATE,
    last_login DATE
)
COMMENT 'Customer information table'
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/customers/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Load data into the table
LOAD DATA INPATH '/data/sample-data/customers.csv' INTO TABLE customers;