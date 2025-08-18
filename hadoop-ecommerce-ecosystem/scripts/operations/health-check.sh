#!/usr/bin/env bash
set -euo pipefail
echo "== ZK =="
for n in master worker1 worker2; do nc -z -v $n 2181 || true; done
echo "== Kafka EXTERNAL =="
for ip in 192.168.235.136 192.168.235.246 192.168.235.147; do nc -z -v $ip 29092 || true; done
echo "== HDFS NN UI =="; curl -sf http://master:9870 | head -n1 || true
echo "== YARN RM UI =="; curl -sf http://master:8088 | head -n1 || true
echo "== Hive =="; nc -z -v master 10000 || true
echo "== Trino =="; curl -sf http://master:8082/v1/info | jq . || true
echo "== Prometheus =="; curl -sf http://master:9090/-/ready || true
echo "== Grafana =="; curl -sf http://master:3000/api/health || true

