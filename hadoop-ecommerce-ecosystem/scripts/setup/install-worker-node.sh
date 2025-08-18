#!/bin/bash

set -e

echo "Cài đặt và cấu hình Worker Node cho Hadoop Ecosystem..."

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[CẢNH BÁO]${NC} $1"; }
log_error() { echo -e "${RED}[LỖI]${NC} $1"; }

# Cài đặt prerequisites (không khởi tạo cluster)
install_prerequisites() {
    log_info "Cài đặt các ứng dụng cần thiết cho Worker Node..."
    
    # Cập nhật hệ thống
    sudo apt-get update -y
    sudo apt-get upgrade -y
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget \
        git \
        vim \
        htop \
        net-tools \
        unzip
    
    # Cài đặt Docker
    install_docker
    
    # Cài đặt Kubernetes tools
    install_kubernetes_tools
    
    # Cài đặt Java
    sudo apt-get install -y openjdk-8-jdk
    
    log_info "Prerequisites đã được cài đặt cho Worker Node"
}

# Cài đặt Docker
install_docker() {
    log_info "Cài đặt Docker..."
    
    # Gỡ bỏ phiên bản cũ
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Thêm GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Thêm repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Thêm user vào nhóm docker
    sudo usermod -aG docker $USER
    
    # Cấu hình Docker daemon
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
    
    sudo systemctl enable docker
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

# Cài đặt Kubernetes tools
install_kubernetes_tools() {
    log_info "Cài đặt Kubernetes tools..."
    
    # Vô hiệu hóa swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Cấu hình kernel modules
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    # Cấu hình sysctl
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sudo sysctl --system
    
    # Thêm GPG key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Thêm repository
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Cài đặt
    sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
}

# Cấu hình Worker Node với tài nguyên 4GB RAM, 2 CPU
configure_worker_node() {
    log_info "Cấu hình Worker Node (4GB RAM, 2 CPU cores)..."
    
    # Tạo thư mục lưu trữ cho worker
    sudo mkdir -p /data/hadoop/{datanode,nodemanager,spark-worker}
    sudo mkdir -p /data/{kafka,hbase,cassandra}
    sudo chown -R $(whoami):$(whoami) /data
    
    log_info "Worker Node storage đã được cấu hình"
}

# Join cluster
join_cluster() {
    echo ""
    echo "=========================================="
    echo "THAM GIA KUBERNETES CLUSTER"
    echo "=========================================="
    echo ""
    
    if [ -z "$1" ]; then
        log_error "Cần cung cấp lệnh join từ Master Node"
        echo "Sử dụng: $0 'sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>'"
        echo ""
        echo "Hoặc lấy lệnh join từ Master Node:"
        echo "sudo kubeadm token create --print-join-command"
        exit 1
    fi
    
    JOIN_COMMAND="$1"
    
    log_info "Tham gia cluster với lệnh: $JOIN_COMMAND"
    
    # Thực hiện join
    eval "$JOIN_COMMAND"
    
    if [ $? -eq 0 ]; then
        log_info "Đã tham gia cluster thành công!"
    else
        log_error "Tham gia cluster thất bại"
        exit 1
    fi
}

# Cấu hình worker sau khi join
post_join_configuration() {
    log_info "Cấu hình Worker Node sau khi join cluster..."
    
    # Chờ node sẵn sàng
    sleep 30
    
    # Tạo script để chạy từ master node
    cat > ~/configure-worker-from-master.sh << EOF
#!/bin/bash
# Script này cần được chạy từ Master Node để cấu hình Worker Node

WORKER_NODE=\$1
if [ -z "\$WORKER_NODE" ]; then
    echo "Sử dụng: \$0 <worker-node-name>"
    echo "Ví dụ: \$0 worker-1"
    exit 1
fi

echo "Cấu hình Worker Node: \$WORKER_NODE"

# Gắn nhãn cho worker node
kubectl label node \$WORKER_NODE node-role=worker --overwrite
kubectl label node \$WORKER_NODE hadoop-role=worker --overwrite

# Tạo PersistentVolumes cho worker node
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: \$WORKER_NODE-datanode-pv
  labels:
    type: local
    component: datanode
    node-role: worker
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data/hadoop/datanode
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - \$WORKER_NODE
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: \$WORKER_NODE-kafka-pv
  labels:
    type: local
    component: kafka
    node-role: worker
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data/kafka
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - \$WORKER_NODE
YAML

echo "Worker Node \$WORKER_NODE đã được cấu hình thành công!"
EOF
    
    chmod +x ~/configure-worker-from-master.sh
    
    echo ""
    echo "=========================================="
    echo "WORKER NODE ĐÃ THAM GIA CLUSTER"
    echo "=========================================="
    echo ""
    echo "Để hoàn tất cấu hình, chạy lệnh sau từ MASTER NODE:"
    echo "scp $(whoami)@$(hostname -I | awk '{print $1}'):~/configure-worker-from-master.sh ."
    echo "./configure-worker-from-master.sh $(hostname)"
    echo ""
    echo "Hoặc chạy trực tiếp từ Master Node:"
    echo "kubectl label node $(hostname) node-role=worker"
    echo "kubectl label node $(hostname) hadoop-role=worker"
}

# Hiển thị thông tin worker node
show_worker_info() {
    echo ""
    echo "=========================================="
    echo "THÔNG TIN WORKER NODE"
    echo "=========================================="
    
    # Thông tin hệ thống
    echo "Hostname: $(hostname)"
    echo "IP Address: $(hostname -I | awk '{print $1}')"
    echo "RAM: $(free -h | awk '/^Mem:/{print $2}')"
    echo "CPU Cores: $(nproc)"
    echo "Disk Space: $(df -h / | awk 'NR==2{print $4}')"
    
    echo ""
    echo "Docker Status:"
    sudo systemctl status docker --no-pager -l
    
    echo ""
    echo "Kubelet Status:"
    sudo systemctl status kubelet --no-pager -l
}

# Tạo script kiểm tra worker
create_worker_check_script() {
    cat > ~/check-worker-status.sh << 'EOF'
#!/bin/bash

echo "Kiểm tra trạng thái Worker Node..."

# Kiểm tra Docker
echo "=== Docker Status ==="
sudo systemctl status docker --no-pager -l

echo ""
echo "=== Kubelet Status ==="
sudo systemctl status kubelet --no-pager -l

echo ""
echo "=== Container Runtime ==="
sudo crictl version 2>/dev/null || echo "crictl không khả dụng"

echo ""
echo "=== Storage Directories ==="
ls -la /data/hadoop/
ls -la /data/

echo ""
echo "=== System Resources ==="
echo "RAM: $(free -h | awk '/^Mem:/{print $2}') total, $(free -h | awk '/^Mem:/{print $7}') available"
echo "CPU: $(nproc) cores"
echo "Disk: $(df -h / | awk 'NR==2{print $4}') free"

echo ""
echo "Worker Node sẵn sàng cho Hadoop workloads!"
EOF
    
    chmod +x ~/check-worker-status.sh
    log_info "Script kiểm tra đã được tạo: ~/check-worker-status.sh"
}

# Hàm chính
main() {
    echo "=========================================="
    echo "CÀI ĐẶT WORKER NODE"
    echo "Cấu hình: 4GB RAM, 2 CPU Cores"
    echo "=========================================="
    echo ""
    
    # Kiểm tra quyền
    if [[ $EUID -eq 0 ]]; then
        log_error "Không chạy script này với quyền root"
        exit 1
    fi
    
    # Kiểm tra tài nguyên hệ thống
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    TOTAL_CPU=$(nproc)
    
    log_info "Tài nguyên hệ thống hiện tại:"
    echo "  - RAM: ${TOTAL_MEM}GB (yêu cầu: ≥4GB)"
    echo "  - CPU: ${TOTAL_CPU} cores (yêu cầu: ≥2 cores)"
    
    if [ "$TOTAL_MEM" -lt 4 ] || [ "$TOTAL_CPU" -lt 2 ]; then
        log_warn "Tài nguyên hệ thống không đủ yêu cầu!"
        read -p "Bạn có muốn tiếp tục? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Thực hiện cài đặt
    install_prerequisites
    configure_worker_node
    
    # Join cluster nếu có tham số
    if [ ! -z "$1" ]; then
        join_cluster "$1"
        post_join_configuration
    else
        echo ""
        echo "=========================================="
        echo "WORKER NODE ĐÃ ĐƯỢC CÀI ĐẶT"
        echo "=========================================="
        echo ""
        echo "Để tham gia cluster, chạy lệnh join từ Master Node:"
        echo "$0 'sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>'"
    fi
    
    show_worker_info
    create_worker_check_script
    
    echo ""
    echo "=========================================="
    echo "CÀI ĐẶT WORKER NODE HOÀN TẤT!"
    echo "=========================================="
    echo ""
    echo "Worker Node đã sẵn sàng với cấu hình:"
    echo "- 4GB RAM, 2 CPU cores"
    echo "- Docker và Kubernetes tools đã được cài đặt"
    echo "- Storage directories đã được tạo"
    echo "- Sẵn sàng cho Hadoop workloads"
}

# Chạy hàm chính
main "$@"