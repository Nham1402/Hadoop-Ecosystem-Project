#!/usr/bin/env bash
set -euo pipefail
echo "== Swarm ==" && docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}' || true
echo "== Nodes ==" && docker node ls || true
echo "== Networks ==" && docker network ls || true
echo "== Volumes ==" && docker volume ls || true
echo "== Stack services ==" && docker stack services hadoop || true
echo "== ZK services ==" && docker service ps --no-trunc hadoop_zk1 || true; docker service ps --no-trunc hadoop_zk2 || true; docker service ps --no-trunc hadoop_zk3 || true
echo "== Kafka services ==" && docker service ps --no-trunc hadoop_kafka1 || true; docker service ps --no-trunc hadoop_kafka2 || true; docker service ps --no-trunc hadoop_kafka3 || true
echo "== Recent logs (ZK1/Kafka1) =="
docker service logs --since 2m hadoop_zk1 | tail -n 200 || true
docker service logs --since 2m hadoop_kafka1 | tail -n 200 || true

