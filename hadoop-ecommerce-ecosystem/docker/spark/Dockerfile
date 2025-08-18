FROM openjdk:8-jdk-slim

LABEL maintainer="Hadoop E-commerce Ecosystem"
LABEL version="3.4.1"

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    python3 \
    python3-pip \
    procps \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV JAVA_HOME=/usr/local/openjdk-8
ENV SPARK_VERSION=3.4.1
ENV HADOOP_VERSION=3.3.4
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.5-src.zip

# Create spark user
RUN useradd -m -s /bin/bash spark && \
    echo "spark:spark" | chpasswd

# Download and install Spark
RUN wget https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz && \
    tar -xzf spark-$SPARK_VERSION-bin-hadoop3.tgz && \
    mv spark-$SPARK_VERSION-bin-hadoop3 $SPARK_HOME && \
    rm spark-$SPARK_VERSION-bin-hadoop3.tgz && \
    chown -R spark:spark $SPARK_HOME

# Install Python dependencies
RUN pip3 install pyspark==$SPARK_VERSION numpy pandas

# Create necessary directories
RUN mkdir -p /opt/spark/logs && \
    mkdir -p /opt/spark/work && \
    mkdir -p /opt/spark/jobs && \
    chown -R spark:spark /opt/spark

# Copy configuration files and scripts
COPY config/* $SPARK_HOME/conf/
COPY scripts/* /scripts/
RUN chmod +x /scripts/*.sh

# Set working directory
WORKDIR $SPARK_HOME

# Switch to spark user
USER spark

# Expose ports
EXPOSE 8080 8081 7077 6066 4040

# Default command
CMD ["bash"]