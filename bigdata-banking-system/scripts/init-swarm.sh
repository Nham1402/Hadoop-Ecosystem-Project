#!/bin/bash

# Big Data Banking System - Docker Swarm Initialization Script
# Chạy script này trên Master Node (192.168.235.136)

set -e

echo "=========================================="
echo "KHỞI TẠO DOCKER SWARM - MASTER NODE"
echo "=========================================="

# Kiểm tra Docker đã được cài đặt chưa
if ! command -v docker &> /dev/null; then
    echo "❌ Docker chưa được cài đặt!"
    echo "Vui lòng cài đặt Docker trước khi chạy script này"
    exit 1
fi

# Kiểm tra Docker service đã chạy chưa
if ! systemctl is-active --quiet docker; then
    echo "🔧 Khởi động Docker service..."
    sudo systemctl start docker
fi

# Lấy IP của Master Node
MASTER_IP="192.168.235.136"
echo "🖥️  Master Node IP: $MASTER_IP"

# Kiểm tra xem node đã là manager chưa
if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    echo "⚠️  Docker Swarm đã được khởi tạo"
    echo "📋 Thông tin cluster hiện tại:"
    docker node ls
else
    echo "🚀 Khởi tạo Docker Swarm..."
    docker swarm init --advertise-addr $MASTER_IP
fi

echo ""
echo "✅ Docker Swarm đã được khởi tạo thành công!"
echo ""

# Lấy join token cho worker nodes
echo "🔑 Lấy token để worker nodes join vào cluster..."
WORKER_TOKEN=$(docker swarm join-token worker -q)

echo ""
echo "=========================================="
echo "WORKER JOIN COMMANDS"
echo "=========================================="
echo ""
echo "📝 Chạy các lệnh sau trên WORKER NODES:"
echo ""
echo "🖥️  WORKER NODE 1 (192.168.235.147):"
echo "docker swarm join --token $WORKER_TOKEN $MASTER_IP:2377"
echo ""
echo "🖥️  WORKER NODE 2 (192.168.235.148):"
echo "docker swarm join --token $WORKER_TOKEN $MASTER_IP:2377"
echo ""

# Label master node
echo "🏷️  Gắn label cho Master Node..."
MASTER_NODE_ID=$(docker node ls --filter role=manager -q)
docker node update --label-add role=master $MASTER_NODE_ID

echo ""
echo "📊 Trạng thái cluster hiện tại:"
docker node ls

# Tạo overlay network
echo ""
echo "🌐 Tạo overlay network cho cluster..."
if docker network ls | grep -q "bigdata-network"; then
    echo "⚠️  Network 'bigdata-network' đã tồn tại"
else
    docker network create -d overlay --attachable bigdata-network
    echo "✅ Đã tạo network 'bigdata-network'"
fi

echo ""
echo "=========================================="
echo "HOÀN TẤT KHỞI TẠO MASTER NODE"
echo "=========================================="
echo ""
echo "📋 Các bước tiếp theo:"
echo "1. Chạy join commands trên các worker nodes"
echo "2. Chạy script 'setup-nodes.sh' để label các worker nodes"
echo "3. Chạy script 'deploy-stack.sh' để triển khai hệ thống"
echo ""
echo "💡 Lưu ý: Đợi tất cả worker nodes join xong trước khi chạy bước tiếp theo!"
echo ""

# Ghi token vào file để dùng sau
echo $WORKER_TOKEN > /tmp/worker-token.txt
echo "💾 Worker token đã được lưu vào /tmp/worker-token.txt"