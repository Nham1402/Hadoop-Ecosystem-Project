#!/bin/bash

echo "Formatting Hadoop Namenode..."

# Format the namenode
$HADOOP_HOME/bin/hdfs namenode -format -force -nonInteractive

echo "Namenode formatting completed."