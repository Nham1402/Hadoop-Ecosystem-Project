#!/bin/bash

echo "Starting Hadoop Datanode..."

# Wait for namenode to be ready
if [ ! -z "$SERVICE_PRECONDITION" ]; then
    /scripts/wait-for-it.sh $SERVICE_PRECONDITION --timeout=60 --strict
fi

# Start datanode
exec $HADOOP_HOME/bin/hdfs datanode