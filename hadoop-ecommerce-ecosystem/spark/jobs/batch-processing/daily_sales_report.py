#!/usr/bin/env python3
"""
Daily Sales Report Generator
Processes order data to generate daily sales analytics
"""

import sys
from datetime import datetime, timedelta
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

def create_spark_session():
    """Create Spark session with Hadoop integration"""
    return SparkSession.builder \
        .appName("DailySalesReport") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .enableHiveSupport() \
        .getOrCreate()

def load_data(spark, date_str=None):
    """Load order and customer data"""
    if date_str is None:
        # Default to yesterday
        date_str = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    
    # Load orders data
    orders_df = spark.sql(f"""
        SELECT * FROM ecommerce.orders 
        WHERE DATE(order_date) = '{date_str}'
        AND order_status IN ('completed', 'delivered')
    """)
    
    # Load customers data
    customers_df = spark.sql("SELECT * FROM ecommerce.customers")
    
    # Load products data
    products_df = spark.sql("SELECT * FROM ecommerce.products")
    
    return orders_df, customers_df, products_df

def generate_sales_metrics(orders_df, customers_df, products_df):
    """Generate comprehensive sales metrics"""
    
    # Join orders with customers and products
    order_details = orders_df \
        .join(customers_df, "customer_id", "left") \
        .join(products_df, orders_df.product_id == products_df.product_id, "left")
    
    # Daily sales summary
    daily_summary = orders_df.agg(
        count("order_id").alias("total_orders"),
        sum("total_amount").alias("total_revenue"),
        avg("total_amount").alias("avg_order_value"),
        sum("tax_amount").alias("total_tax"),
        sum("shipping_amount").alias("total_shipping"),
        sum("discount_amount").alias("total_discounts")
    )
    
    # Sales by state
    sales_by_state = orders_df \
        .join(customers_df, "customer_id") \
        .groupBy("state") \
        .agg(
            count("order_id").alias("orders_count"),
            sum("total_amount").alias("revenue"),
            avg("total_amount").alias("avg_order_value")
        ) \
        .orderBy(desc("revenue"))
    
    # Sales by payment method
    sales_by_payment = orders_df \
        .groupBy("payment_method") \
        .agg(
            count("order_id").alias("orders_count"),
            sum("total_amount").alias("revenue")
        ) \
        .orderBy(desc("revenue"))
    
    # Top customers by spending
    top_customers = orders_df \
        .join(customers_df, "customer_id") \
        .groupBy("customer_id", "first_name", "last_name", "email") \
        .agg(
            count("order_id").alias("orders_count"),
            sum("total_amount").alias("total_spent")
        ) \
        .orderBy(desc("total_spent")) \
        .limit(10)
    
    return daily_summary, sales_by_state, sales_by_payment, top_customers

def save_results(spark, daily_summary, sales_by_state, sales_by_payment, top_customers, date_str):
    """Save results to HDFS and Hive tables"""
    
    # Add date column to all dataframes
    daily_summary = daily_summary.withColumn("report_date", lit(date_str))
    sales_by_state = sales_by_state.withColumn("report_date", lit(date_str))
    sales_by_payment = sales_by_payment.withColumn("report_date", lit(date_str))
    top_customers = top_customers.withColumn("report_date", lit(date_str))
    
    # Save to HDFS as Parquet
    base_path = f"/analytics/daily_reports/{date_str}"
    
    daily_summary.coalesce(1).write \
        .mode("overwrite") \
        .parquet(f"{base_path}/daily_summary")
    
    sales_by_state.coalesce(1).write \
        .mode("overwrite") \
        .parquet(f"{base_path}/sales_by_state")
    
    sales_by_payment.coalesce(1).write \
        .mode("overwrite") \
        .parquet(f"{base_path}/sales_by_payment")
    
    top_customers.coalesce(1).write \
        .mode("overwrite") \
        .parquet(f"{base_path}/top_customers")
    
    # Also save to Hive tables for easy querying
    daily_summary.write \
        .mode("append") \
        .saveAsTable("ecommerce.daily_sales_summary")
    
    sales_by_state.write \
        .mode("append") \
        .saveAsTable("ecommerce.sales_by_state")
    
    print(f"Daily sales report for {date_str} saved successfully!")

def print_summary(daily_summary, sales_by_state, sales_by_payment, top_customers):
    """Print summary to console"""
    print("\n" + "="*50)
    print("DAILY SALES REPORT SUMMARY")
    print("="*50)
    
    summary_data = daily_summary.collect()[0]
    print(f"Total Orders: {summary_data['total_orders']}")
    print(f"Total Revenue: ${summary_data['total_revenue']:,.2f}")
    print(f"Average Order Value: ${summary_data['avg_order_value']:,.2f}")
    print(f"Total Tax: ${summary_data['total_tax']:,.2f}")
    print(f"Total Shipping: ${summary_data['total_shipping']:,.2f}")
    print(f"Total Discounts: ${summary_data['total_discounts']:,.2f}")
    
    print("\nTOP 5 STATES BY REVENUE:")
    sales_by_state.show(5, False)
    
    print("\nSALES BY PAYMENT METHOD:")
    sales_by_payment.show(False)
    
    print("\nTOP 5 CUSTOMERS:")
    top_customers.show(5, False)

def main():
    """Main function"""
    # Get date from command line argument or use yesterday
    date_str = sys.argv[1] if len(sys.argv) > 1 else None
    
    # Create Spark session
    spark = create_spark_session()
    spark.sparkContext.setLogLevel("WARN")
    
    try:
        # Load data
        print(f"Loading data for date: {date_str or 'yesterday'}")
        orders_df, customers_df, products_df = load_data(spark, date_str)
        
        if orders_df.count() == 0:
            print("No orders found for the specified date.")
            return
        
        # Generate metrics
        print("Generating sales metrics...")
        daily_summary, sales_by_state, sales_by_payment, top_customers = \
            generate_sales_metrics(orders_df, customers_df, products_df)
        
        # Save results
        final_date = date_str or (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        save_results(spark, daily_summary, sales_by_state, sales_by_payment, top_customers, final_date)
        
        # Print summary
        print_summary(daily_summary, sales_by_state, sales_by_payment, top_customers)
        
    except Exception as e:
        print(f"Error processing daily sales report: {str(e)}")
        raise
    finally:
        spark.stop()

if __name__ == "__main__":
    main()