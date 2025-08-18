from datetime import datetime
from airflow import DAG
from airflow.operators.empty import EmptyOperator


with DAG(
    dag_id="real_time_analytics",
    start_date=datetime(2024, 4, 1),
    schedule=None,
    catchup=False,
) as dag:
    start = EmptyOperator(task_id="start")

