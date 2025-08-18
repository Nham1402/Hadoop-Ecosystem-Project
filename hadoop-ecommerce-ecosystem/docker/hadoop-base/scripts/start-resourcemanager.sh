#!/bin/bash

echo "Starting YARN ResourceManager..."

# Wait for namenode to be ready
if [ ! -z "$SERVICE_PRECONDITION" ]; then
    /scripts/wait-for-it.sh $SERVICE_PRECONDITION --timeout=60 --strict
fi

# Start ResourceManager
exec $HADOOP_HOME/bin/yarn resourcemanager