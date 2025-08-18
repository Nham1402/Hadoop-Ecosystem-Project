SHELL := /usr/bin/bash

.PHONY: help up down logs kafka-topic spark-job hdfs-put airflow

help:
	@echo "Targets:"
	@echo "  up           - docker-compose up -d"
	@echo "  down         - docker-compose down -v"
	@echo "  logs         - docker-compose logs -f"
	@echo "  kafka-topic  - create kafka topic user-events"
	@echo "  hdfs-put     - put sample data to HDFS (docker env)"
	@echo "  spark-job    - run daily_sales_report in docker env"

up:
	docker compose -f docker-compose.yml up -d

down:
	docker compose -f docker-compose.yml down -v

logs:
	docker compose -f docker-compose.yml logs -f

kafka-topic:
	docker compose exec kafka kafka-topics.sh --create --topic user-events --bootstrap-server kafka:9092 --replication-factor 1 --partitions 3 || true

hdfs-put:
	@echo "Uploading sample CSVs into HDFS (docker namenode)"
	docker compose exec namenode hdfs dfs -mkdir -p /data/raw
	docker compose cp data/sample-data/. namenode:/tmp/sample
	docker compose exec namenode hdfs dfs -put -f /tmp/sample/*.csv /data/raw/

spark-job:
	@echo "Submitting Spark job (daily_sales_report)"
	docker compose cp spark/jobs/batch-processing/daily_sales_report.py spark-master:/tmp/dsr.py
	docker compose exec spark-master spark-submit --master spark://spark-master:7077 /tmp/dsr.py --input hdfs://namenode:9000/data/raw/orders.csv --products hdfs://namenode:9000/data/raw/products.csv --output hdfs://namenode:9000/reports/daily_sales
