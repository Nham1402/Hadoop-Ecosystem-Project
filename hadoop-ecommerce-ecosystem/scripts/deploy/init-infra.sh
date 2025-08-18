#!/usr/bin/env bash
set -euo pipefail

echo "Creating overlay networks (if not exist)"
docker network create -d overlay --attachable data-net || true
docker network create -d overlay --attachable kafka-net || true
docker network create -d overlay --attachable monitoring-net || true

echo "Creating local volumes on this node (others must be created on their nodes too)"
for v in zk1-data zk2-data zk3-data nn-data dn-data kafka1-data kafka2-data kafka3-data hive-metastore-pg hive-warehouse trino-data prometheus-data grafana-data elastic-data; do
  docker volume create "$v" >/dev/null || true
done

echo "Done. Remember to create worker volumes on worker nodes for services scheduled there."

