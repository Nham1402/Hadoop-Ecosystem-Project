#!/bin/bash

set -e

echo "Cài đặt Kubernetes tools (kubectl, kubeadm, kubelet)..."

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[CẢNH BÁO]${NC} $1"; }
log_error() { echo -e "${RED}[LỖI]${NC} $1"; }

# Cấu hình hệ thống cho Kubernetes
configure_system() {
    log_info "Cấu hình hệ thống cho Kubernetes..."
    
    # Vô hiệu hóa swap (nếu có)
    if swapon --show | grep -q "/"; then
        log_info "Vô hiệu hóa swap..."
        sudo swapoff -a
        sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    fi
    
    # Load kernel modules
    log_info "Load kernel modules..."
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    sudo modprobe overlay 2>/dev/null || log_warn "Không thể load module overlay"
    sudo modprobe br_netfilter 2>/dev/null || log_warn "Không thể load module br_netfilter"
    
    # Cấu hình sysctl
    log_info "Cấu hình sysctl..."
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sudo sysctl --system >/dev/null 2>&1 || log_warn "Một số sysctl settings không thể áp dụng"
}

# Cài đặt Kubernetes tools
install_kubernetes_tools() {
    log_info "Cài đặt Kubernetes tools..."
    
    # Thêm GPG key
    log_info "Thêm Kubernetes GPG key..."
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Thêm repository
    log_info "Thêm Kubernetes repository..."
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Cài đặt
    log_info "Cài đặt kubelet, kubeadm, kubectl..."
    sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    
    # Kiểm tra cài đặt
    log_info "Kiểm tra cài đặt..."
    kubectl version --client
    kubeadm version
}

# Cài đặt Helm
install_helm() {
    log_info "Cài đặt Helm..."
    
    # Thêm GPG key
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    
    # Thêm repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    
    # Cài đặt
    sudo apt-get update -y
    sudo apt-get install -y helm
    
    # Kiểm tra
    helm version
}

# Cài đặt Java (cần cho Hadoop)
install_java() {
    log_info "Cài đặt OpenJDK 8..."
    sudo apt-get install -y openjdk-8-jdk
    
    # Thiết lập JAVA_HOME
    echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> ~/.bashrc
    echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.bashrc
    
    java -version
}

# Hiển thị hướng dẫn tiếp theo
show_next_steps() {
    echo ""
    echo "=========================================="
    echo "CÀI ĐẶT HOÀN TẤT!"
    echo "=========================================="
    echo ""
    echo "Các công cụ đã được cài đặt:"
    echo "✓ Docker: $(docker --version)"
    echo "✓ kubectl: $(kubectl version --client --short 2>/dev/null)"
    echo "✓ kubeadm: $(kubeadm version -o short)"
    echo "✓ Helm: $(helm version --short)"
    echo "✓ Java: $(java -version 2>&1 | head -n1)"
    echo ""
    echo "Bước tiếp theo:"
    echo "1. Khởi tạo Kubernetes cluster (chỉ trên master node):"
    echo "   sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
    echo ""
    echo "2. Cấu hình kubectl:"
    echo "   mkdir -p ~/.kube"
    echo "   sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config"
    echo "   sudo chown \$(id -u):\$(id -g) ~/.kube/config"
    echo ""
    echo "3. Cài đặt CNI (Flannel):"
    echo "   kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
    echo ""
    echo "4. Triển khai Hadoop ecosystem:"
    echo "   make deploy"
}

# Hàm chính
main() {
    configure_system
    install_kubernetes_tools
    install_helm
    install_java
    show_next_steps
}

# Chạy
main "$@"