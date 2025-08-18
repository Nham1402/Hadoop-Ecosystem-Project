#!/bin/bash

echo "Starting YARN NodeManager..."

# Wait for dependencies
if [ ! -z "$SERVICE_PRECONDITION" ]; then
    IFS=' ' read -ra DEPS <<< "$SERVICE_PRECONDITION"
    for dep in "${DEPS[@]}"; do
        /scripts/wait-for-it.sh $dep --timeout=60 --strict
    done
fi

# Start NodeManager
exec $HADOOP_HOME/bin/yarn nodemanager