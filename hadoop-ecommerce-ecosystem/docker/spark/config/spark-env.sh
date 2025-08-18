#!/usr/bin/env bash

# Spark Environment Configuration

# Java home
export JAVA_HOME=${JAVA_HOME:-/usr/local/openjdk-8}

# Spark home
export SPARK_HOME=${SPARK_HOME:-/opt/spark}

# Hadoop configuration
export HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-/opt/hadoop/etc/hadoop}

# Python configuration
export PYSPARK_PYTHON=python3
export PYSPARK_DRIVER_PYTHON=python3

# Spark master configuration
export SPARK_MASTER_HOST=${SPARK_MASTER_HOST:-0.0.0.0}
export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-7077}
export SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT:-8080}

# Spark worker configuration
export SPARK_WORKER_CORES=${SPARK_WORKER_CORES:-2}
export SPARK_WORKER_MEMORY=${SPARK_WORKER_MEMORY:-3g}
export SPARK_WORKER_PORT=${SPARK_WORKER_PORT:-7078}
export SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT:-8081}
export SPARK_WORKER_DIR=${SPARK_WORKER_DIR:-/opt/spark/work}

# Spark daemon memory
export SPARK_DAEMON_MEMORY=${SPARK_DAEMON_MEMORY:-1g}

# Spark history server
export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=18080 -Dspark.history.retainedApplications=50 -Dspark.history.fs.logDirectory=hdfs://namenode:8020/spark-logs"

# JVM options
export SPARK_MASTER_OPTS="-Xmx1g -XX:+UseG1GC"
export SPARK_WORKER_OPTS="-Xmx1g -XX:+UseG1GC"

# Log configuration
export SPARK_LOG_DIR=${SPARK_LOG_DIR:-/opt/spark/logs}
export SPARK_PID_DIR=${SPARK_PID_DIR:-/tmp}

# Classpath
export SPARK_DIST_CLASSPATH=$(hadoop classpath)

# Driver and executor options
export SPARK_DRIVER_MEMORY=${SPARK_DRIVER_MEMORY:-1g}
export SPARK_EXECUTOR_MEMORY=${SPARK_EXECUTOR_MEMORY:-2g}

# Enable JMX monitoring
export SPARK_MASTER_OPTS="$SPARK_MASTER_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8090 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
export SPARK_WORKER_OPTS="$SPARK_WORKER_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=8091 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"