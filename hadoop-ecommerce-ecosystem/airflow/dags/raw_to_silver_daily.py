from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="raw_to_silver_daily",
    start_date=datetime(2024, 1, 1),
    schedule_interval="0 2 * * *",
    catchup=False,
) as dag:
    check_trino = BashOperator(
        task_id="check_trino",
        bash_command="curl -sf http://trino-coordinator:8080/v1/info | jq .version || true",
    )

    list_hdfs = BashOperator(
        task_id="list_hdfs",
        bash_command="hdfs dfs -ls / || true",
    )

    check_trino >> list_hdfs

