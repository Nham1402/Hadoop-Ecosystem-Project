"""
Daily ETL Pipeline DAG for E-commerce Analytics
Processes daily sales data and generates reports
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.http.sensors.http import HttpSensor
from airflow.models import Variable

# Default arguments
default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'catchup': False
}

# Create DAG
dag = DAG(
    'daily_etl_pipeline',
    default_args=default_args,
    description='Daily ETL pipeline for e-commerce analytics',
    schedule_interval='0 2 * * *',  # Run at 2 AM daily
    max_active_runs=1,
    tags=['etl', 'daily', 'ecommerce']
)

# Check if Hadoop NameNode is healthy
check_namenode = HttpSensor(
    task_id='check_namenode_health',
    http_conn_id='namenode_http',
    endpoint='/',
    timeout=60,
    poke_interval=30,
    dag=dag
)

# Check if Spark Master is healthy
check_spark_master = HttpSensor(
    task_id='check_spark_master_health',
    http_conn_id='spark_master_http',
    endpoint='/',
    timeout=60,
    poke_interval=30,
    dag=dag
)

# Create HDFS directories for daily data
create_hdfs_dirs = BashOperator(
    task_id='create_hdfs_directories',
    bash_command="""
    DATE={{ ds }}
    hdfs dfs -mkdir -p /data/raw/orders/$DATE
    hdfs dfs -mkdir -p /data/raw/customers/$DATE
    hdfs dfs -mkdir -p /data/raw/products/$DATE
    hdfs dfs -mkdir -p /analytics/daily_reports/$DATE
    """,
    dag=dag
)

# Load sample data to HDFS
load_sample_data = BashOperator(
    task_id='load_sample_data',
    bash_command="""
    DATE={{ ds }}
    # Copy sample data to HDFS
    hdfs dfs -put /opt/airflow/data/sample-data/customers.csv /data/raw/customers/$DATE/
    hdfs dfs -put /opt/airflow/data/sample-data/products.csv /data/raw/products/$DATE/
    hdfs dfs -put /opt/airflow/data/sample-data/orders.csv /data/raw/orders/$DATE/
    """,
    dag=dag
)

# Create Hive tables
create_hive_tables = BashOperator(
    task_id='create_hive_tables',
    bash_command="""
    beeline -u "jdbc:hive2://hiveserver2:10000" -f /opt/airflow/data/schemas/hive/customers.sql
    beeline -u "jdbc:hive2://hiveserver2:10000" -f /opt/airflow/data/schemas/hive/products.sql
    beeline -u "jdbc:hive2://hiveserver2:10000" -f /opt/airflow/data/schemas/hive/orders.sql
    """,
    dag=dag
)

# Run data quality checks
def run_data_quality_checks(**context):
    """Run basic data quality checks"""
    from pyspark.sql import SparkSession
    
    spark = SparkSession.builder \
        .appName("DataQualityChecks") \
        .enableHiveSupport() \
        .getOrCreate()
    
    try:
        # Check if tables exist and have data
        customers_count = spark.sql("SELECT COUNT(*) FROM ecommerce.customers").collect()[0][0]
        products_count = spark.sql("SELECT COUNT(*) FROM ecommerce.products").collect()[0][0]
        orders_count = spark.sql("SELECT COUNT(*) FROM ecommerce.orders").collect()[0][0]
        
        print(f"Data quality check results:")
        print(f"Customers: {customers_count} records")
        print(f"Products: {products_count} records")
        print(f"Orders: {orders_count} records")
        
        # Basic validation
        if customers_count == 0 or products_count == 0:
            raise ValueError("Critical tables are empty!")
        
        # Check for null values in critical fields
        null_emails = spark.sql("SELECT COUNT(*) FROM ecommerce.customers WHERE email IS NULL").collect()[0][0]
        null_prices = spark.sql("SELECT COUNT(*) FROM ecommerce.products WHERE price IS NULL").collect()[0][0]
        
        if null_emails > 0:
            print(f"Warning: {null_emails} customers with null emails")
        if null_prices > 0:
            print(f"Warning: {null_prices} products with null prices")
        
        return True
        
    except Exception as e:
        print(f"Data quality check failed: {str(e)}")
        raise
    finally:
        spark.stop()

data_quality_check = PythonOperator(
    task_id='data_quality_check',
    python_callable=run_data_quality_checks,
    dag=dag
)

# Generate daily sales report using Spark
generate_daily_report = BashOperator(
    task_id='generate_daily_sales_report',
    bash_command="""
    spark-submit \
        --master spark://spark-master:7077 \
        --deploy-mode client \
        --executor-memory 2g \
        --executor-cores 2 \
        --num-executors 2 \
        /opt/airflow/spark/jobs/batch-processing/daily_sales_report.py {{ ds }}
    """,
    dag=dag
)

# Customer segmentation analysis
customer_segmentation = BashOperator(
    task_id='customer_segmentation_analysis',
    bash_command="""
    spark-submit \
        --master spark://spark-master:7077 \
        --deploy-mode client \
        --executor-memory 2g \
        --executor-cores 2 \
        --num-executors 2 \
        /opt/airflow/spark/jobs/batch-processing/customer_segmentation.py {{ ds }}
    """,
    dag=dag
)

# Product recommendation engine
product_recommendations = BashOperator(
    task_id='generate_product_recommendations',
    bash_command="""
    spark-submit \
        --master spark://spark-master:7077 \
        --deploy-mode client \
        --executor-memory 2g \
        --executor-cores 2 \
        --num-executors 2 \
        /opt/airflow/spark/jobs/ml/collaborative_filtering.py {{ ds }}
    """,
    dag=dag
)

# Archive processed data
archive_data = BashOperator(
    task_id='archive_processed_data',
    bash_command="""
    DATE={{ ds }}
    # Archive raw data to long-term storage
    hdfs dfs -mkdir -p /archive/raw/$DATE
    hdfs dfs -cp /data/raw/orders/$DATE /archive/raw/$DATE/
    hdfs dfs -cp /data/raw/customers/$DATE /archive/raw/$DATE/
    hdfs dfs -cp /data/raw/products/$DATE /archive/raw/$DATE/
    
    # Clean up temporary files older than 7 days
    hdfs dfs -rm -r -f /tmp/spark-*
    """,
    dag=dag
)

# Send notification
def send_completion_notification(**context):
    """Send completion notification"""
    execution_date = context['ds']
    print(f"Daily ETL pipeline completed successfully for {execution_date}")
    # Here you would typically send email, Slack notification, etc.
    return f"Pipeline completed for {execution_date}"

send_notification = PythonOperator(
    task_id='send_completion_notification',
    python_callable=send_completion_notification,
    dag=dag
)

# Define task dependencies
check_namenode >> create_hdfs_dirs
check_spark_master >> create_hdfs_dirs
create_hdfs_dirs >> load_sample_data >> create_hive_tables
create_hive_tables >> data_quality_check
data_quality_check >> [generate_daily_report, customer_segmentation, product_recommendations]
[generate_daily_report, customer_segmentation, product_recommendations] >> archive_data
archive_data >> send_notification