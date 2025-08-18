FROM openjdk:8-jdk-slim

LABEL maintainer="Hadoop E-commerce Ecosystem"
LABEL version="3.3.4"

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ssh \
    rsync \
    vim \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV JAVA_HOME=/usr/local/openjdk-8
ENV HADOOP_VERSION=3.3.4
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# Create hadoop user
RUN useradd -m -s /bin/bash hadoop && \
    echo "hadoop:hadoop" | chpasswd && \
    usermod -aG sudo hadoop

# Download and install Hadoop
RUN wget https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz && \
    tar -xzf hadoop-$HADOOP_VERSION.tar.gz && \
    mv hadoop-$HADOOP_VERSION $HADOOP_HOME && \
    rm hadoop-$HADOOP_VERSION.tar.gz && \
    chown -R hadoop:hadoop $HADOOP_HOME

# Create necessary directories
RUN mkdir -p /hadoop/logs && \
    mkdir -p /hadoop/dfs/name && \
    mkdir -p /hadoop/dfs/data && \
    chown -R hadoop:hadoop /hadoop

# SSH setup for passwordless SSH
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

# Copy configuration files
COPY config/* $HADOOP_CONF_DIR/
COPY scripts/* /scripts/
RUN chmod +x /scripts/*.sh

# Set working directory
WORKDIR $HADOOP_HOME

# Switch to hadoop user
USER hadoop

# Expose ports
EXPOSE 8020 9000 9870 8088 8042 19888 10020 10033

# Default command
CMD ["bash"]