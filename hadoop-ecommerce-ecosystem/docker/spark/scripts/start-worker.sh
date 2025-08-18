#!/bin/bash

echo "Starting Spark Worker..."

if [ $# -ne 1 ]; then
    echo "Usage: $0 <master-url>"
    exit 1
fi

MASTER_URL=$1

# Create necessary directories
mkdir -p /opt/spark/logs
mkdir -p /opt/spark/work

# Start Spark Worker
exec $SPARK_HOME/bin/spark-class org.apache.spark.deploy.worker.Worker \
    --webui-port $SPARK_WORKER_WEBUI_PORT \
    --port $SPARK_WORKER_PORT \
    --cores $SPARK_WORKER_CORES \
    --memory $SPARK_WORKER_MEMORY \
    --work-dir $SPARK_WORKER_DIR \
    $MASTER_URL