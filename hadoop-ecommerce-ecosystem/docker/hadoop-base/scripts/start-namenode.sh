#!/bin/bash

echo "Starting Hadoop Namenode..."

# Wait for dependencies
if [ ! -z "$SERVICE_PRECONDITION" ]; then
    /scripts/wait-for-it.sh $SERVICE_PRECONDITION --timeout=60 --strict
fi

# Format namenode if not already formatted
if [ ! -d "/hadoop/dfs/name/current" ]; then
    echo "Formatting namenode..."
    $HADOOP_HOME/bin/hdfs namenode -format -force -nonInteractive
fi

# Start namenode
exec $HADOOP_HOME/bin/hdfs namenode