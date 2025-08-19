#!/bin/bash

# Big Data Banking System - Stack Deployment Script
# Chạy script này trên Master Node để triển khai toàn bộ hệ thống

set -e

echo "=========================================="
echo "TRIỂN KHAI HỆ THỐNG BIG DATA BANKING"
echo "=========================================="

# Kiểm tra prerequisite
echo "🔍 Kiểm tra điều kiện cần thiết..."

# Kiểm tra Docker Swarm
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    echo "❌ Docker Swarm chưa được khởi tạo!"
    echo "Chạy ./scripts/init-swarm.sh trước"
    exit 1
fi

# Kiểm tra số lượng nodes
EXPECTED_NODES=3
CURRENT_NODES=$(docker node ls --format "table {{.ID}}" | wc -l)
CURRENT_NODES=$((CURRENT_NODES - 1))

if [ $CURRENT_NODES -lt $EXPECTED_NODES ]; then
    echo "❌ Không đủ nodes! Cần $EXPECTED_NODES nodes"
    exit 1
fi

# Kiểm tra file cấu hình
if [ ! -f ".env" ]; then
    echo "❌ File .env không tồn tại!"
    echo "Tạo file .env từ template"
    exit 1
fi

if [ ! -f "docker-compose.yml" ]; then
    echo "❌ File docker-compose.yml không tồn tại!"
    exit 1
fi

echo "✅ Tất cả điều kiện đã sẵn sàng"

# Load environment variables
source .env

echo ""
echo "📋 Thông tin cấu hình:"
echo "   Master IP: $MASTER_IP"
echo "   Worker 1 IP: $WORKER1_IP"  
echo "   Worker 2 IP: $WORKER2_IP"
echo "   MySQL Database: $MYSQL_DATABASE"
echo ""

# Tạo các file cấu hình cần thiết
echo "📁 Tạo các file cấu hình..."

# MySQL init script
cat > configs/mysql/init.sql << 'EOF'
-- Banking Metadata Database Initialization

CREATE DATABASE IF NOT EXISTS banking_metadata;
USE banking_metadata;

-- Airflow tables will be created automatically

-- Hive Metastore tables
CREATE TABLE IF NOT EXISTS SEQUENCE_TABLE (
    SEQUENCE_NAME VARCHAR(255) NOT NULL,
    NEXT_VAL BIGINT NOT NULL,
    PRIMARY KEY (SEQUENCE_NAME)
);

-- Insert initial sequence values
INSERT IGNORE INTO SEQUENCE_TABLE (SEQUENCE_NAME, NEXT_VAL) VALUES 
('org.apache.hadoop.hive.metastore.model.MDatabase', 1),
('org.apache.hadoop.hive.metastore.model.MTable', 1),
('org.apache.hadoop.hive.metastore.model.MPartition', 1);

-- Banking specific tables
CREATE TABLE IF NOT EXISTS banking_customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS banking_accounts (
    account_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    account_type VARCHAR(20),
    balance DECIMAL(15,2),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES banking_customers(customer_id)
);

CREATE TABLE IF NOT EXISTS banking_transactions (
    transaction_id VARCHAR(30) PRIMARY KEY,
    from_account VARCHAR(20),
    to_account VARCHAR(20),
    amount DECIMAL(15,2),
    transaction_type VARCHAR(20),
    status VARCHAR(20),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT IGNORE INTO banking_customers VALUES 
('CUST001', 'Nguyen', 'Van A', 'nva@email.com', '0901234567', 'Ha Noi', NOW()),
('CUST002', 'Tran', 'Thi B', 'ttb@email.com', '0902345678', 'Ho Chi Minh', NOW()),
('CUST003', 'Le', 'Van C', 'lvc@email.com', '0903456789', 'Da Nang', NOW());

INSERT IGNORE INTO banking_accounts VALUES 
('ACC001', 'CUST001', 'CHECKING', 50000000.00, 'ACTIVE', NOW()),
('ACC002', 'CUST002', 'SAVINGS', 75000000.00, 'ACTIVE', NOW()),
('ACC003', 'CUST003', 'CHECKING', 30000000.00, 'ACTIVE', NOW());

INSERT IGNORE INTO banking_transactions VALUES 
('TXN001', 'ACC001', 'ACC002', 1000000.00, 'TRANSFER', 'COMPLETED', NOW()),
('TXN002', 'ACC002', 'ACC003', 500000.00, 'TRANSFER', 'COMPLETED', NOW()),
('TXN003', 'ACC001', 'ACC003', 2000000.00, 'TRANSFER', 'PENDING', NOW());

EOF

# Hadoop core-site.xml
cat > configs/hadoop/core-site.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://namenode:8020</value>
    </property>
    <property>
        <name>hadoop.http.staticuser.user</name>
        <value>root</value>
    </property>
    <property>
        <name>hadoop.proxyuser.root.hosts</name>
        <value>*</value>
    </property>
    <property>
        <name>hadoop.proxyuser.root.groups</name>
        <value>*</value>
    </property>
</configuration>
EOF

# Hadoop hdfs-site.xml
cat > configs/hadoop/hdfs-site.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/hadoop/dfs/name</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/hadoop/dfs/data</value>
    </property>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.permissions.enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
    </property>
</configuration>
EOF

# Spark configuration
cat > configs/spark/spark-defaults.conf << 'EOF'
spark.master                     spark://spark-master:7077
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://namenode:8020/spark-logs
spark.sql.warehouse.dir          hdfs://namenode:8020/spark-warehouse
spark.serializer                 org.apache.spark.serializer.KryoSerializer
spark.sql.adaptive.enabled       true
spark.sql.adaptive.coalescePartitions.enabled true
spark.hadoop.fs.defaultFS        hdfs://namenode:8020
spark.sql.catalogImplementation  hive
spark.sql.hive.metastore.version 3.1.3
spark.sql.hive.metastore.jars    builtin
EOF

# Prometheus configuration
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'hadoop-namenode'
    static_configs:
      - targets: ['namenode:9870']

  - job_name: 'hadoop-resourcemanager'
    static_configs:
      - targets: ['resourcemanager:8088']

  - job_name: 'spark-master'
    static_configs:
      - targets: ['spark-master:8080']

  - job_name: 'kafka'
    static_configs:
      - targets: ['kafka-1:29092', 'kafka-2:29093', 'kafka-3:29094']
EOF

echo "✅ Đã tạo các file cấu hình"

# Pull các images trước khi deploy
echo ""
echo "🐳 Pull Docker images..."
docker pull mysql:8.0
docker pull confluentinc/cp-zookeeper:7.4.0
docker pull confluentinc/cp-kafka:7.4.0
docker pull apache/hadoop:3.3.6
docker pull bitnami/spark:3.5
docker pull apache/airflow:2.7.2

echo "✅ Đã pull các Docker images cần thiết"

# Deploy stack
echo ""
echo "🚀 Triển khai Big Data Banking Stack..."
echo "Tên stack: banking-stack"

docker stack deploy -c docker-compose.yml banking-stack

echo ""
echo "⏳ Đợi các services khởi động..."

# Đợi các services cơ bản
sleep 30

echo ""
echo "📊 Kiểm tra trạng thái services:"
docker service ls

echo ""
echo "🔍 Kiểm tra trạng thái containers:"
docker stack ps banking-stack

# Đợi MySQL và Zookeeper khởi động
echo ""
echo "⏳ Đợi MySQL và Zookeeper khởi động hoàn tất..."
sleep 60

# Kiểm tra health của các services chính
echo ""
echo "🏥 Kiểm tra health các services chính..."

check_service() {
    local service_name=$1
    local port=$2
    local host=${3:-localhost}
    
    echo -n "Checking $service_name..."
    if curl -s -f http://$host:$port > /dev/null 2>&1; then
        echo " ✅"
    else
        echo " ❌"
    fi
}

echo ""
echo "Đợi thêm 60s để services hoàn tất khởi động..."
sleep 60

# Tạo Kafka topics cho banking
echo ""
echo "📝 Tạo Kafka topics cho banking system..."

# Đợi Kafka cluster sẵn sàng
sleep 30

# Tạo topics
docker exec -i $(docker ps -q -f name=banking-stack_kafka-1) kafka-topics --create --topic banking-transactions --bootstrap-server localhost:29092 --partitions 3 --replication-factor 3 --if-not-exists
docker exec -i $(docker ps -q -f name=banking-stack_kafka-1) kafka-topics --create --topic fraud-alerts --bootstrap-server localhost:29092 --partitions 3 --replication-factor 3 --if-not-exists  
docker exec -i $(docker ps -q -f name=banking-stack_kafka-1) kafka-topics --create --topic risk-events --bootstrap-server localhost:29092 --partitions 3 --replication-factor 3 --if-not-exists

echo "✅ Đã tạo Kafka topics"

# Khởi tạo HDFS directories
echo ""
echo "📁 Khởi tạo HDFS directories..."
sleep 10

docker exec -i $(docker ps -q -f name=banking-stack_namenode) hdfs dfsadmin -safemode leave || true
docker exec -i $(docker ps -q -f name=banking-stack_namenode) hdfs dfs -mkdir -p /user/hive/warehouse || true
docker exec -i $(docker ps -q -f name=banking-stack_namenode) hdfs dfs -mkdir -p /spark-logs || true
docker exec -i $(docker ps -q -f name=banking-stack_namenode) hdfs dfs -mkdir -p /banking-data || true
docker exec -i $(docker ps -q -f name=banking-stack_namenode) hdfs dfs -chmod 777 /user/hive/warehouse || true
docker exec -i $(docker ps -q -f name=banking-stack_namenode) hdfs dfs -chmod 777 /spark-logs || true

echo "✅ Đã khởi tạo HDFS directories"

echo ""
echo "=========================================="
echo "TRIỂN KHAI HOÀN TẤT!"
echo "=========================================="
echo ""
echo "🎉 Hệ thống Big Data Banking đã được triển khai thành công!"
echo ""
echo "🌐 CÁC URL TRUY CẬP (từ bên ngoài):"
echo ""
echo "📊 HADOOP ECOSYSTEM:"
echo "   • NameNode WebUI:      http://$MASTER_IP:9870"
echo "   • YARN ResourceMgr:    http://$MASTER_IP:8088"
echo ""
echo "⚡ SPARK:"
echo "   • Master WebUI:        http://$MASTER_IP:8080"
echo ""
echo "🏛️  HBASE:"
echo "   • Master WebUI:        http://$MASTER_IP:16010"
echo ""
echo "📨 KAFKA:"
echo "   • Kafka UI:            http://$MASTER_IP:8090"
echo "   • Schema Registry:     http://$MASTER_IP:8085"
echo ""
echo "🔄 AIRFLOW:"
echo "   • Web Interface:       http://$MASTER_IP:8081"
echo "   • Username/Password:   $AIRFLOW_USER/$AIRFLOW_PASSWORD"
echo ""
echo "📊 MONITORING:"
echo "   • Grafana:             http://$MASTER_IP:3000"
echo "   • Username/Password:   admin/$GRAFANA_PASSWORD"
echo "   • Prometheus:          http://$MASTER_IP:9090"
echo ""
echo "🔬 DEVELOPMENT:"
echo "   • Jupyter Notebook:    http://$MASTER_IP:8888"
echo ""
echo "🗄️  DATABASE:"
echo "   • MySQL:               $MASTER_IP:3306"
echo "   • Database:            $MYSQL_DATABASE"
echo "   • Username/Password:   $MYSQL_USER/$MYSQL_PASSWORD"
echo ""
echo "📋 TRẠNG THÁI SERVICES:"
docker service ls
echo ""
echo "💡 LƯU Ý:"
echo "   • Một số services có thể cần thêm thời gian để khởi động hoàn toàn"
echo "   • Kiểm tra logs nếu có service nào lỗi: docker service logs <service_name>"
echo "   • Jupyter token có thể lấy từ: docker service logs banking-stack_jupyter"
echo ""
echo "🚀 Hệ thống đã sẵn sàng xử lý dữ liệu banking!"