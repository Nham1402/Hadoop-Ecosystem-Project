#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root_dir"

echo "[1/10] Zookeeper"
docker stack deploy -c docker/zookeeper/docker-compose.yml hadoop

echo "[2/10] Kafka"
docker stack deploy -c docker/kafka/docker-compose.yml hadoop

echo "[3/10] HDFS + [4/10] YARN"
docker stack deploy -c docker/hadoop-base/docker-compose.yml hadoop

echo "[5/10] Hive"
docker stack deploy -c docker/hive/docker-compose.yml hadoop

echo "[6/10] HBase"
docker stack deploy -c docker/hbase/docker-compose.yml hadoop || true

echo "[7/10] Spark"
docker stack deploy -c docker/spark/docker-compose.yml hadoop

echo "[8/10] Airflow"
docker stack deploy -c docker/airflow/docker-compose.yml hadoop

echo "[9/10] Trino"
docker stack deploy -c docker/trino/docker-compose.yml hadoop

echo "[10/10] Monitoring"
docker stack deploy -c docker/monitoring/docker-compose.yml hadoop

echo "Done. Check services: docker service ls"

