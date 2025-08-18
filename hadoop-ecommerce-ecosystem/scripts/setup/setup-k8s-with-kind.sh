#!/bin/bash

set -e

echo "Cài đặt Kubernetes với kind (Kubernetes in Docker)..."

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

# Cài đặt kind
install_kind() {
    log_info "Cài đặt kind (Kubernetes in Docker)..."
    
    # Tải kind binary
    KIND_VERSION="v0.20.0"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    # Kiểm tra cài đặt
    kind version
}

# Khởi động Docker service (nếu cần)
start_docker() {
    log_info "Khởi động Docker service..."
    
    # Trong môi trường container, Docker daemon có thể cần được khởi động thủ công
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker daemon chưa chạy. Thử khởi động..."
        
        # Thử khởi động dockerd trong background
        sudo dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 &
        
        # Chờ Docker sẵn sàng
        for i in {1..30}; do
            if docker info >/dev/null 2>&1; then
                log_success "Docker daemon đã sẵn sàng"
                break
            fi
            echo "Chờ Docker daemon... ($i/30)"
            sleep 2
        done
        
        if ! docker info >/dev/null 2>&1; then
            log_error "Không thể khởi động Docker daemon"
            return 1
        fi
    else
        log_success "Docker daemon đã chạy"
    fi
}

# Tạo kind cluster với cấu hình phù hợp
create_kind_cluster() {
    log_info "Tạo kind cluster với cấu hình Hadoop..."
    
    # Tạo file cấu hình kind
    cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: hadoop-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-role=master,hadoop-role=master"
  extraMounts:
  - hostPath: /tmp/kind-data
    containerPath: /data
  extraPortMappings:
  - containerPort: 30870
    hostPort: 30870
    protocol: TCP
  - containerPort: 30088
    hostPort: 30088
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30300
    hostPort: 30300
    protocol: TCP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-role=worker,hadoop-role=worker"
  extraMounts:
  - hostPath: /tmp/kind-data-worker1
    containerPath: /data
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-role=worker,hadoop-role=worker"
  extraMounts:
  - hostPath: /tmp/kind-data-worker2
    containerPath: /data
EOF

    # Tạo thư mục data trên host
    sudo mkdir -p /tmp/kind-data /tmp/kind-data-worker1 /tmp/kind-data-worker2
    sudo chmod 777 /tmp/kind-data /tmp/kind-data-worker1 /tmp/kind-data-worker2
    
    # Tạo cluster
    kind create cluster --config=kind-config.yaml
    
    # Cấu hình kubectl
    kubectl cluster-info --context kind-hadoop-cluster
}

# Cài đặt CNI và các add-ons cần thiết
setup_cluster_addons() {
    log_info "Cài đặt cluster add-ons..."
    
    # Chờ cluster sẵn sàng
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Cài đặt MetalLB cho LoadBalancer support
    log_info "Cài đặt MetalLB..."
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    
    # Chờ MetalLB pods sẵn sàng
    kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
    
    # Cấu hình MetalLB address pool
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
    
    log_success "MetalLB đã được cấu hình"
}

# Tạo namespace và resource quota
setup_hadoop_namespace() {
    log_info "Tạo namespace hadoop-ecosystem..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: hadoop-ecosystem
  labels:
    name: hadoop-ecosystem
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: hadoop-quota
  namespace: hadoop-ecosystem
spec:
  hard:
    requests.cpu: "7"
    requests.memory: "14Gi"
    limits.cpu: "7"
    limits.memory: "14Gi"
    persistentvolumeclaims: "20"
    services: "20"
EOF
    
    log_success "Namespace hadoop-ecosystem đã được tạo"
}

# Hiển thị thông tin cluster
show_cluster_info() {
    echo ""
    echo "=========================================="
    echo "THÔNG TIN KUBERNETES CLUSTER"
    echo "=========================================="
    
    echo ""
    echo "Nodes:"
    kubectl get nodes -o wide
    
    echo ""
    echo "Cluster Info:"
    kubectl cluster-info
    
    echo ""
    echo "Namespaces:"
    kubectl get namespaces
    
    echo ""
    echo "Storage Classes:"
    kubectl get storageclass
}

# Tạo script để dọn dẹp
create_cleanup_script() {
    cat > cleanup-kind-cluster.sh << 'EOF'
#!/bin/bash
echo "Dọn dẹp kind cluster..."
kind delete cluster --name hadoop-cluster
sudo rm -rf /tmp/kind-data /tmp/kind-data-worker1 /tmp/kind-data-worker2
rm -f kind-config.yaml
echo "Cluster đã được xóa!"
EOF
    
    chmod +x cleanup-kind-cluster.sh
    log_info "Script dọn dẹp đã được tạo: cleanup-kind-cluster.sh"
}

# Hiển thị hướng dẫn tiếp theo
show_next_steps() {
    echo ""
    echo "=========================================="
    echo "KUBERNETES CLUSTER ĐÃ SẴN SÀNG!"
    echo "=========================================="
    echo ""
    echo "Cluster Information:"
    echo "- Name: hadoop-cluster"
    echo "- Nodes: 1 master + 2 workers"
    echo "- Context: kind-hadoop-cluster"
    echo ""
    echo "Các lệnh hữu ích:"
    echo "kubectl get nodes                    # Xem nodes"
    echo "kubectl get pods -A                  # Xem tất cả pods"
    echo "kubectl config current-context       # Xem context hiện tại"
    echo ""
    echo "Truy cập services từ bên ngoài:"
    echo "- Hadoop NameNode: http://localhost:30870"
    echo "- YARN ResourceManager: http://localhost:30088"
    echo "- Spark Master: http://localhost:30080"
    echo "- Grafana: http://localhost:30300"
    echo ""
    echo "Triển khai Hadoop ecosystem:"
    echo "make deploy"
    echo ""
    echo "Để xóa cluster:"
    echo "./cleanup-kind-cluster.sh"
}

# Hàm chính
main() {
    log_info "Bắt đầu cài đặt Kubernetes với kind..."
    
    start_docker
    install_kind
    create_kind_cluster
    setup_cluster_addons
    setup_hadoop_namespace
    show_cluster_info
    create_cleanup_script
    show_next_steps
    
    log_success "Cài đặt hoàn tất!"
}

# Chạy hàm chính
main "$@"