#!/usr/bin/env bash
set -euo pipefail
cid=$(docker ps --filter name=hadoop_namenode -q | head -n1)
if [ -z "$cid" ]; then
  echo "Namenode container not found. Make sure HDFS stack is up." >&2
  exit 1
fi
echo "Formatting HDFS namenode inside container $cid"
docker exec -it "$cid" bash -lc "hdfs namenode -format -force && start-dfs.sh" || true
echo "Creating Spark history directory"
docker exec -it "$cid" bash -lc "hdfs dfs -mkdir -p /spark-history && hdfs dfs -chmod -R 777 /spark-history" || true

