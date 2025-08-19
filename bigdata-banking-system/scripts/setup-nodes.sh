#!/bin/bash

# Big Data Banking System - Node Setup Script
# Chạy script này trên Master Node sau khi tất cả worker nodes đã join

set -e

echo "=========================================="
echo "THIẾT LẬP VÀ LABEL CÁC NODES"
echo "=========================================="

# Kiểm tra tất cả nodes đã join chưa
EXPECTED_NODES=3
CURRENT_NODES=$(docker node ls --format "table {{.ID}}" | wc -l)
CURRENT_NODES=$((CURRENT_NODES - 1))  # Trừ header line

echo "🔍 Kiểm tra số lượng nodes..."
echo "📊 Nodes hiện tại: $CURRENT_NODES/$EXPECTED_NODES"

if [ $CURRENT_NODES -lt $EXPECTED_NODES ]; then
    echo "⚠️  Chưa đủ nodes! Cần $EXPECTED_NODES nodes nhưng chỉ có $CURRENT_NODES"
    echo "📋 Danh sách nodes hiện tại:"
    docker node ls
    echo ""
    echo "❗ Vui lòng đảm bảo tất cả worker nodes đã join cluster trước khi tiếp tục"
    read -p "Bấm Enter để tiếp tục hoặc Ctrl+C để thoát..." -r
fi

echo ""
echo "📋 Danh sách nodes hiện tại:"
docker node ls

echo ""
echo "🏷️  Gắn labels cho các nodes..."

# Label Master Node (đã được label trong init-swarm.sh)
MASTER_NODE_ID=$(docker node ls --filter role=manager -q)
docker node update --label-add role=master $MASTER_NODE_ID
echo "✅ Master Node đã được label"

# Label Worker Nodes
echo ""
echo "🔍 Tìm và label Worker Nodes..."

# Lấy danh sách tất cả worker nodes
WORKER_NODES=($(docker node ls --filter role=worker --format "{{.ID}}"))

if [ ${#WORKER_NODES[@]} -ge 1 ]; then
    echo "🏷️  Label Worker Node 1..."
    docker node update --label-add role=worker1 ${WORKER_NODES[0]}
    WORKER1_HOSTNAME=$(docker node inspect ${WORKER_NODES[0]} --format "{{.Description.Hostname}}")
    echo "✅ Worker Node 1 (${WORKER1_HOSTNAME}) đã được label"
fi

if [ ${#WORKER_NODES[@]} -ge 2 ]; then
    echo "🏷️  Label Worker Node 2..."
    docker node update --label-add role=worker2 ${WORKER_NODES[1]}
    WORKER2_HOSTNAME=$(docker node inspect ${WORKER_NODES[1]} --format "{{.Description.Hostname}}")
    echo "✅ Worker Node 2 (${WORKER2_HOSTNAME}) đã được label"
fi

echo ""
echo "📊 Kiểm tra labels đã được gắn:"
echo ""
for node_id in $(docker node ls -q); do
    hostname=$(docker node inspect $node_id --format "{{.Description.Hostname}}")
    role=$(docker node inspect $node_id --format "{{.Spec.Role}}")
    labels=$(docker node inspect $node_id --format '{{json .Spec.Labels}}')
    echo "🖥️  Node: $hostname ($role)"
    echo "   Labels: $labels"
    echo ""
done


# Kiểm tra overlay network
echo "🌐 Kiểm tra overlay network..."
if docker network ls | grep -q "bigdata-network"; then
    echo "✅ Network 'bigdata-network' đã sẵn sàng"
else
    echo "🌐 Tạo overlay network..."
    docker network create -d overlay --attachable bigdata-network
    echo "✅ Đã tạo network 'bigdata-network'"
fi

# Tạo các thư mục cần thiết
echo ""
echo "📁 Tạo cấu trúc thư mục..."

mkdir -p {configs/{hadoop,spark,hive,hbase,kafka,flume,airflow,mysql},data/banking-sample,dags,spark-jobs,notebooks,monitoring/grafana/{dashboards,provisioning}}

echo "✅ Đã tạo cấu trúc thư mục"

# Kiểm tra resource trên các nodes
echo ""
echo "💾 Kiểm tra tài nguyên hệ thống:"

for node_id in $(docker node ls -q); do
    hostname=$(docker node inspect $node_id --format "{{.Description.Hostname}}")
    echo ""
    echo "🖥️  Node: $hostname"
    
    # Sử dụng docker node inspect để lấy thông tin resource
    resources=$(docker node inspect $node_id --format "{{.Description.Resources}}")
    echo "   Resources: $resources"
done

echo ""
echo "=========================================="
echo "HOÀN TẤT THIẾT LẬP NODES"
echo "=========================================="
echo ""
echo "✅ Tất cả nodes đã được thiết lập và label thành công!"
echo ""
echo "📋 Cấu trúc cluster:"
echo "   🖥️  Master Node (192.168.235.136): role=master"
echo "   🖥️  Worker Node 1 (192.168.235.147): role=worker1"
echo "   🖥️  Worker Node 2 (192.168.235.148): role=worker2"
echo ""
echo "🌐 Network: bigdata-network (overlay)"
echo ""
echo "🚀 Sẵn sàng để deploy stack!"
echo "   Chạy: ./scripts/deploy-stack.sh"
echo ""

# Test connectivity giữa các nodes
echo "🔍 Test connectivity giữa các nodes..."
echo "Ping test sẽ được thực hiện khi deploy containers"