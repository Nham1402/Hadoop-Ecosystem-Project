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
