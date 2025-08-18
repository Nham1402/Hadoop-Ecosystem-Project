from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator


default_args = {
    "owner": "data-eng",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}


with DAG(
    dag_id="daily_etl_pipeline",
    default_args=default_args,
    schedule="0 2 * * *",
    start_date=datetime(2024, 4, 1),
    catchup=False,
) as dag:

    create_hdfs_dirs = BashOperator(
        task_id="create_hdfs_dirs",
        bash_command="hdfs dfs -mkdir -p /data/raw /reports/daily_sales || true",
    )

    load_sample_data = BashOperator(
        task_id="load_sample_data",
        bash_command=(
            "hdfs dfs -put -f /workspace/hadoop-ecommerce-ecosystem/data/sample-data/*.csv /data/raw/"
        ),
    )

    spark_daily_sales = BashOperator(
        task_id="spark_daily_sales",
        bash_command=(
            "/opt/spark/bin/spark-submit --master spark://hd-master:7077 "
            "/workspace/hadoop-ecommerce-ecosystem/spark/jobs/batch-processing/daily_sales_report.py "
            "--input /data/raw/orders.csv --products /data/raw/products.csv "
            "--output /reports/daily_sales"
        ),
    )

    create_hdfs_dirs >> load_sample_data >> spark_daily_sales

