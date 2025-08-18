#!/bin/bash

set -e

echo "Demo Setup - Hadoop E-commerce Ecosystem (Local Environment)"

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[CẢNH BÁO]${NC} $1"; }
log_error() { echo -e "${RED}[LỖI]${NC} $1"; }
log_success() { echo -e "${BLUE}[THÀNH CÔNG]${NC} $1"; }

# Hiển thị thông tin môi trường
show_environment_info() {
    echo ""
    echo "=========================================="
    echo "THÔNG TIN MÔI TRƯỜNG HIỆN TẠI"
    echo "=========================================="
    
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "RAM: $(free -h | awk '/^Mem:/{print $2}')"
    echo "CPU: $(nproc) cores"
    echo "Disk: $(df -h / | awk 'NR==2{print $4}' | head -1) free"
    echo ""
    
    # Kiểm tra Docker
    if command -v docker &> /dev/null; then
        if docker info >/dev/null 2>&1; then
            log_success "Docker: $(docker --version) - RUNNING"
        else
            log_warn "Docker: $(docker --version) - NOT RUNNING"
        fi
    else
        log_warn "Docker: Not installed"
    fi
    
    # Kiểm tra kubectl
    if command -v kubectl &> /dev/null; then
        if kubectl cluster-info >/dev/null 2>&1; then
            log_success "kubectl: $(kubectl version --client --short 2>/dev/null) - CONNECTED"
        else
            log_warn "kubectl: $(kubectl version --client --short 2>/dev/null) - NOT CONNECTED"
        fi
    else
        log_warn "kubectl: Not installed"
    fi
    
    # Kiểm tra Java
    if command -v java &> /dev/null; then
        log_success "Java: $(java -version 2>&1 | head -n1)"
    else
        log_warn "Java: Not installed"
    fi
}

# Tạo demo Docker Compose setup
create_demo_docker_compose() {
    log_info "Tạo Docker Compose demo setup..."
    
    cat > docker-compose-demo.yml << 'EOF'
version: '3.8'

services:
  # Zookeeper
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    hostname: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    volumes:
      - zookeeper-data:/var/lib/zookeeper/data

  # Kafka
  kafka:
    image: confluentinc/cp-kafka:7.4.0
    hostname: kafka
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
    volumes:
      - kafka-data:/var/lib/kafka/data

  # PostgreSQL
  postgres:
    image: postgres:13
    hostname: postgres
    environment:
      POSTGRES_DB: ecommerce
      POSTGRES_USER: hadoop
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data

  # Hadoop NameNode (Simplified)
  namenode:
    image: bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8
    hostname: namenode
    ports:
      - "9870:9870"
      - "8020:8020"
    environment:
      - CLUSTER_NAME=hadoop-demo
      - CORE_CONF_fs_defaultFS=hdfs://namenode:8020
    volumes:
      - namenode-data:/hadoop/dfs/name
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1'

  # Hadoop DataNode
  datanode:
    image: bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8
    hostname: datanode
    depends_on:
      - namenode
    ports:
      - "9864:9864"
    environment:
      - CORE_CONF_fs_defaultFS=hdfs://namenode:8020
    volumes:
      - datanode-data:/hadoop/dfs/data
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1'

  # Spark Master
  spark-master:
    image: bde2020/spark-master:3.1.1-hadoop3.2
    hostname: spark-master
    ports:
      - "8080:8080"
      - "7077:7077"
    environment:
      - INIT_DAEMON_STEP=setup_spark
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1'

  # Spark Worker
  spark-worker:
    image: bde2020/spark-worker:3.1.1-hadoop3.2
    hostname: spark-worker
    depends_on:
      - spark-master
    ports:
      - "8081:8081"
    environment:
      - SPARK_MASTER=spark://spark-master:7077
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1'

  # Grafana
  grafana:
    image: grafana/grafana:latest
    hostname: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana

  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    hostname: prometheus
    ports:
      - "9090:9090"
    volumes:
      - prometheus-data:/prometheus

volumes:
  zookeeper-data:
  kafka-data:
  postgres-data:
  namenode-data:
  datanode-data:
  grafana-data:
  prometheus-data:

networks:
  default:
    driver: bridge
EOF

    log_success "Docker Compose demo file đã được tạo: docker-compose-demo.yml"
}

# Tạo scripts demo
create_demo_scripts() {
    log_info "Tạo demo scripts..."
    
    # Script khởi động demo
    cat > start-demo.sh << 'EOF'
#!/bin/bash

echo "Khởi động Hadoop E-commerce Demo..."

# Kiểm tra Docker
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon không chạy!"
    echo "Hãy khởi động Docker trước khi chạy demo."
    exit 1
fi

# Khởi động services
echo "Khởi động các services..."
docker-compose -f docker-compose-demo.yml up -d

# Chờ services sẵn sàng
echo "Chờ services khởi động..."
sleep 30

# Kiểm tra trạng thái
echo ""
echo "=== TRẠNG THÁI SERVICES ==="
docker-compose -f docker-compose-demo.yml ps

echo ""
echo "=== TRUY CẬP WEB UIs ==="
echo "Hadoop NameNode: http://localhost:9870"
echo "Spark Master: http://localhost:8080"
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo ""
echo "=== DATABASE ==="
echo "PostgreSQL: localhost:5432"
echo "  Database: ecommerce"
echo "  User: hadoop"
echo "  Password: password"
echo ""
echo "Demo đã sẵn sàng!"
EOF

    # Script dừng demo
    cat > stop-demo.sh << 'EOF'
#!/bin/bash

echo "Dừng Hadoop E-commerce Demo..."

# Dừng tất cả services
docker-compose -f docker-compose-demo.yml down

echo "Demo đã được dừng."
EOF

    # Script dọn dẹp demo
    cat > cleanup-demo.sh << 'EOF'
#!/bin/bash

echo "Dọn dẹp Hadoop E-commerce Demo..."

# Dừng và xóa containers, volumes
docker-compose -f docker-compose-demo.yml down -v

# Xóa images (tùy chọn)
read -p "Bạn có muốn xóa Docker images không? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose -f docker-compose-demo.yml down --rmi all -v
fi

echo "Demo đã được dọn dẹp."
EOF

    chmod +x start-demo.sh stop-demo.sh cleanup-demo.sh
    
    log_success "Demo scripts đã được tạo:"
    echo "  - start-demo.sh: Khởi động demo"
    echo "  - stop-demo.sh: Dừng demo"
    echo "  - cleanup-demo.sh: Dọn dẹp demo"
}

# Tạo sample data cho demo
create_sample_data() {
    log_info "Tạo sample data cho demo..."
    
    mkdir -p demo-data
    
    # Tạo sample SQL cho PostgreSQL
    cat > demo-data/sample-data.sql << 'EOF'
-- Sample E-commerce Data for Demo

-- Create tables
CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    city VARCHAR(50),
    state VARCHAR(50),
    registration_date DATE
);

CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    brand VARCHAR(50),
    price DECIMAL(10,2),
    stock_quantity INTEGER
);

CREATE TABLE IF NOT EXISTS orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    order_date TIMESTAMP,
    total_amount DECIMAL(10,2),
    order_status VARCHAR(20)
);

-- Insert sample data
INSERT INTO customers (first_name, last_name, email, phone, city, state, registration_date) VALUES
('John', 'Doe', 'john.doe@email.com', '+1-555-0101', 'New York', 'NY', '2023-01-15'),
('Jane', 'Smith', 'jane.smith@email.com', '+1-555-0102', 'Los Angeles', 'CA', '2023-02-20'),
('Mike', 'Johnson', 'mike.johnson@email.com', '+1-555-0103', 'Chicago', 'IL', '2023-03-10'),
('Sarah', 'Williams', 'sarah.williams@email.com', '+1-555-0104', 'Houston', 'TX', '2023-04-05'),
('David', 'Brown', 'david.brown@email.com', '+1-555-0105', 'Phoenix', 'AZ', '2023-05-12');

INSERT INTO products (product_name, category, brand, price, stock_quantity) VALUES
('iPhone 14 Pro', 'Electronics', 'Apple', 999.99, 50),
('Samsung Galaxy S23', 'Electronics', 'Samsung', 799.99, 75),
('MacBook Air M2', 'Electronics', 'Apple', 1199.99, 30),
('Nike Air Max 270', 'Footwear', 'Nike', 130.00, 100),
('Adidas Ultraboost 22', 'Footwear', 'Adidas', 180.00, 80);

INSERT INTO orders (customer_id, order_date, total_amount, order_status) VALUES
(1, '2024-01-01 10:30:00', 1059.99, 'completed'),
(2, '2024-01-02 14:15:00', 829.99, 'completed'),
(3, '2024-01-03 09:45:00', 1319.98, 'shipped'),
(4, '2024-01-04 16:20:00', 189.99, 'processing'),
(5, '2024-01-05 11:10:00', 409.98, 'completed');
EOF

    # Tạo script load data
    cat > demo-data/load-sample-data.sh << 'EOF'
#!/bin/bash

echo "Loading sample data into PostgreSQL..."

# Chờ PostgreSQL sẵn sàng
sleep 10

# Load data
docker exec -i $(docker-compose -f docker-compose-demo.yml ps -q postgres) psql -U hadoop -d ecommerce < demo-data/sample-data.sql

echo "Sample data loaded successfully!"
echo ""
echo "Connect to database:"
echo "psql -h localhost -U hadoop -d ecommerce"
echo "Password: password"
EOF

    chmod +x demo-data/load-sample-data.sh
    
    log_success "Sample data đã được tạo trong thư mục demo-data/"
}

# Hiển thị hướng dẫn sử dụng demo
show_demo_usage() {
    echo ""
    echo "=========================================="
    echo "HƯỚNG DẪN SỬ DỤNG DEMO"
    echo "=========================================="
    echo ""
    echo "🚀 Khởi động demo:"
    echo "   ./start-demo.sh"
    echo ""
    echo "🌐 Truy cập Web UIs:"
    echo "   - Hadoop NameNode: http://localhost:9870"
    echo "   - Spark Master: http://localhost:8080"
    echo "   - Grafana: http://localhost:3000 (admin/admin)"
    echo "   - Prometheus: http://localhost:9090"
    echo ""
    echo "💾 Load sample data:"
    echo "   ./demo-data/load-sample-data.sh"
    echo ""
    echo "🗄️ Kết nối database:"
    echo "   psql -h localhost -U hadoop -d ecommerce"
    echo "   Password: password"
    echo ""
    echo "⏹️ Dừng demo:"
    echo "   ./stop-demo.sh"
    echo ""
    echo "🧹 Dọn dẹp demo:"
    echo "   ./cleanup-demo.sh"
    echo ""
    echo "📋 Xem trạng thái:"
    echo "   docker-compose -f docker-compose-demo.yml ps"
    echo ""
    echo "📊 Xem logs:"
    echo "   docker-compose -f docker-compose-demo.yml logs [service-name]"
}

# Tạo README cho demo
create_demo_readme() {
    cat > DEMO_README.md << 'EOF'
# Hadoop E-commerce Ecosystem - Demo

## Giới thiệu

Đây là phiên bản demo đơn giản của Hadoop E-commerce Ecosystem sử dụng Docker Compose, phù hợp để chạy trên máy local hoặc môi trường có hạn chế.

## Yêu cầu

- Docker và Docker Compose
- 4GB RAM trở lên
- 10GB disk space trống

## Cấu trúc Demo

```
├── docker-compose-demo.yml    # Docker Compose configuration
├── start-demo.sh             # Script khởi động
├── stop-demo.sh              # Script dừng
├── cleanup-demo.sh           # Script dọn dẹp
└── demo-data/
    ├── sample-data.sql       # Sample database
    └── load-sample-data.sh   # Script load data
```

## Các Services

- **Zookeeper**: Coordination service
- **Kafka**: Message streaming
- **PostgreSQL**: Relational database
- **Hadoop NameNode**: HDFS metadata
- **Hadoop DataNode**: HDFS storage
- **Spark Master**: Spark cluster coordinator
- **Spark Worker**: Spark processing node
- **Grafana**: Monitoring dashboard
- **Prometheus**: Metrics collection

## Cách sử dụng

### 1. Khởi động demo
```bash
./start-demo.sh
```

### 2. Load sample data
```bash
./demo-data/load-sample-data.sh
```

### 3. Truy cập Web UIs
- Hadoop NameNode: http://localhost:9870
- Spark Master: http://localhost:8080
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

### 4. Kết nối database
```bash
psql -h localhost -U hadoop -d ecommerce
# Password: password
```

### 5. Dừng demo
```bash
./stop-demo.sh
```

### 6. Dọn dẹp (xóa tất cả data)
```bash
./cleanup-demo.sh
```

## Giám sát

- **Logs**: `docker-compose -f docker-compose-demo.yml logs [service]`
- **Status**: `docker-compose -f docker-compose-demo.yml ps`
- **Stats**: `docker stats`

## Hạn chế của Demo

- Chỉ 1 DataNode và 1 Spark Worker
- Không có High Availability
- Không có security
- Tài nguyên hạn chế
- Không có persistent storage optimization

## Chuyển sang Production

Để triển khai production, sử dụng:
- Kubernetes manifests trong thư mục `kubernetes/`
- Helm charts trong thư mục `helm/`
- Scripts cài đặt trong `scripts/setup/`

Xem `HUONG_DAN_CAI_DAT_THUC_TE.md` để biết chi tiết.
EOF

    log_success "Demo README đã được tạo: DEMO_README.md"
}

# Hàm chính
main() {
    echo ""
    echo "=========================================="
    echo "HADOOP E-COMMERCE ECOSYSTEM - DEMO SETUP"
    echo "=========================================="
    
    show_environment_info
    
    echo ""
    log_info "Tạo demo environment cho Hadoop E-commerce Ecosystem..."
    
    create_demo_docker_compose
    create_demo_scripts
    create_sample_data
    create_demo_readme
    
    show_demo_usage
    
    echo ""
    log_success "Demo setup hoàn tất!"
    echo ""
    echo "📝 Lưu ý quan trọng:"
    echo "   - Demo này chỉ phù hợp để test và học tập"
    echo "   - Để triển khai thực tế, sử dụng Kubernetes"
    echo "   - Xem HUONG_DAN_CAI_DAT_THUC_TE.md để cài đặt production"
    echo ""
    echo "🚀 Bắt đầu demo ngay:"
    echo "   ./start-demo.sh"
}

# Chạy hàm chính
main "$@"