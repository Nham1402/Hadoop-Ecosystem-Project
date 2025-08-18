#!/bin/bash

echo "Starting Spark Master..."

# Create necessary directories
mkdir -p /opt/spark/logs
mkdir -p /opt/spark/work

# Start Spark Master
exec $SPARK_HOME/bin/spark-class org.apache.spark.deploy.master.Master \
    --host $SPARK_MASTER_HOST \
    --port $SPARK_MASTER_PORT \
    --webui-port $SPARK_MASTER_WEBUI_PORT