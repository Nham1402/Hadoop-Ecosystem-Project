#!/bin/bash

set -e

echo "Cài đặt các ứng dụng cần thiết cho Hadoop E-commerce Ecosystem..."

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[CẢNH BÁO]${NC} $1"
}

log_error() {
    echo -e "${RED}[LỖI]${NC} $1"
}

log_success() {
    echo -e "${BLUE}[THÀNH CÔNG]${NC} $1"
}

# Kiểm tra hệ điều hành
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "Không thể xác định hệ điều hành"
        exit 1
    fi
    
    log_info "Hệ điều hành: $OS $VER"
    
    if [[ $OS != *"Ubuntu"* ]]; then
        log_warn "Script này được tối ưu cho Ubuntu. Hệ thống hiện tại: $OS"
        read -p "Bạn có muốn tiếp tục? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Cập nhật hệ thống
update_system() {
    log_info "Cập nhật hệ thống..."
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
    
    log_success "Cập nhật hệ thống hoàn tất"
}

# Cài đặt Docker
install_docker() {
    log_info "Cài đặt Docker..."
    
    # Gỡ bỏ các phiên bản cũ
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Thêm GPG key của Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Thêm repository Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt Docker
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Thêm user vào nhóm docker
    sudo usermod -aG docker $USER
    
    # Cấu hình Docker daemon
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "registry-mirrors": ["https://mirror.gcr.io"]
}
EOF
    
    # Khởi động Docker
    sudo systemctl enable docker
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    # Kiểm tra Docker
    if sudo docker --version; then
        log_success "Docker đã được cài đặt thành công: $(sudo docker --version)"
    else
        log_error "Cài đặt Docker thất bại"
        exit 1
    fi
}

# Cài đặt Docker Compose (standalone)
install_docker_compose() {
    log_info "Cài đặt Docker Compose..."
    
    # Tải Docker Compose
    DOCKER_COMPOSE_VERSION="2.24.1"
    sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Phân quyền thực thi
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Tạo symbolic link
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Kiểm tra
    if docker-compose --version; then
        log_success "Docker Compose đã được cài đặt: $(docker-compose --version)"
    else
        log_error "Cài đặt Docker Compose thất bại"
        exit 1
    fi
}

# Cài đặt Kubernetes tools
install_kubernetes() {
    log_info "Cài đặt Kubernetes tools (kubeadm, kubelet, kubectl)..."
    
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
    
    # Thêm GPG key của Kubernetes
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Thêm repository Kubernetes
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Cài đặt Kubernetes tools
    sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    
    # Kiểm tra
    if kubectl version --client; then
        log_success "Kubernetes tools đã được cài đặt thành công"
        echo "  - kubeadm: $(kubeadm version -o short)"
        echo "  - kubelet: $(kubelet --version)"
        echo "  - kubectl: $(kubectl version --client -o yaml | grep gitVersion)"
    else
        log_error "Cài đặt Kubernetes tools thất bại"
        exit 1
    fi
}

# Cài đặt Helm
install_helm() {
    log_info "Cài đặt Helm..."
    
    # Thêm GPG key của Helm
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    
    # Thêm repository Helm
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    
    # Cài đặt Helm
    sudo apt-get update -y
    sudo apt-get install -y helm
    
    # Kiểm tra
    if helm version; then
        log_success "Helm đã được cài đặt: $(helm version --short)"
    else
        log_error "Cài đặt Helm thất bại"
        exit 1
    fi
}

# Cài đặt các công cụ bổ sung
install_additional_tools() {
    log_info "Cài đặt các công cụ bổ sung..."
    
    # K9s - Kubernetes CLI
    log_info "Cài đặt k9s..."
    K9S_VERSION="v0.28.2"
    wget -q https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz
    tar -xzf k9s_Linux_amd64.tar.gz
    sudo mv k9s /usr/local/bin/
    rm k9s_Linux_amd64.tar.gz
    
    # Kubectx và kubens
    log_info "Cài đặt kubectx và kubens..."
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
    sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
    
    # Java (cần cho Hadoop)
    log_info "Cài đặt OpenJDK 8..."
    sudo apt-get install -y openjdk-8-jdk
    
    # Python và pip
    log_info "Cài đặt Python và các thư viện..."
    sudo apt-get install -y python3 python3-pip
    pip3 install --user pyyaml kubernetes
    
    log_success "Các công cụ bổ sung đã được cài đặt"
}

# Cấu hình firewall (tùy chọn)
configure_firewall() {
    read -p "Bạn có muốn cấu hình firewall cho Kubernetes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cấu hình firewall..."
        
        # Cài đặt ufw nếu chưa có
        sudo apt-get install -y ufw
        
        # Cấu hình các port cần thiết
        sudo ufw allow ssh
        sudo ufw allow 6443/tcp    # Kubernetes API server
        sudo ufw allow 2379:2380/tcp  # etcd server client API
        sudo ufw allow 10250/tcp   # Kubelet API
        sudo ufw allow 10259/tcp   # kube-scheduler
        sudo ufw allow 10257/tcp   # kube-controller-manager
        sudo ufw allow 30000:32767/tcp  # NodePort Services
        
        # Hadoop ports
        sudo ufw allow 8020/tcp    # HDFS NameNode
        sudo ufw allow 9870/tcp    # HDFS NameNode Web UI
        sudo ufw allow 8088/tcp    # YARN ResourceManager
        sudo ufw allow 8080/tcp    # Spark Master Web UI
        sudo ufw allow 7077/tcp    # Spark Master
        
        log_success "Firewall đã được cấu hình"
    fi
}

# Khởi tạo Kubernetes cluster
init_kubernetes_cluster() {
    read -p "Đây có phải là node master không? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Khởi tạo Kubernetes cluster..."
        
        # Khởi tạo cluster
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(hostname -I | awk '{print $1}')
        
        # Cấu hình kubectl cho user hiện tại
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        # Cài đặt Flannel CNI
        kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        
        # Cho phép scheduling trên master node (cho môi trường test)
        kubectl taint nodes --all node-role.kubernetes.io/control-plane-
        
        log_success "Kubernetes cluster đã được khởi tạo thành công!"
        
        # Hiển thị lệnh join
        echo ""
        echo "=========================================="
        echo "LỆNH JOIN CHO WORKER NODES:"
        echo "=========================================="
        sudo kubeadm token create --print-join-command
        echo "=========================================="
        echo ""
        
    else
        log_info "Node worker - Chạy lệnh join từ master node để tham gia cluster"
    fi
}

# Kiểm tra cài đặt
verify_installation() {
    log_info "Kiểm tra cài đặt..."
    
    echo ""
    echo "=== KIỂM TRA CÀI ĐẶT ==="
    
    # Docker
    if command -v docker &> /dev/null; then
        echo "✓ Docker: $(docker --version)"
    else
        echo "✗ Docker: Chưa cài đặt"
    fi
    
    # Docker Compose
    if command -v docker-compose &> /dev/null; then
        echo "✓ Docker Compose: $(docker-compose --version)"
    else
        echo "✗ Docker Compose: Chưa cài đặt"
    fi
    
    # Kubectl
    if command -v kubectl &> /dev/null; then
        echo "✓ Kubectl: $(kubectl version --client --short 2>/dev/null)"
    else
        echo "✗ Kubectl: Chưa cài đặt"
    fi
    
    # Kubeadm
    if command -v kubeadm &> /dev/null; then
        echo "✓ Kubeadm: $(kubeadm version -o short)"
    else
        echo "✗ Kubeadm: Chưa cài đặt"
    fi
    
    # Helm
    if command -v helm &> /dev/null; then
        echo "✓ Helm: $(helm version --short)"
    else
        echo "✗ Helm: Chưa cài đặt"
    fi
    
    # Java
    if command -v java &> /dev/null; then
        echo "✓ Java: $(java -version 2>&1 | head -n 1)"
    else
        echo "✗ Java: Chưa cài đặt"
    fi
    
    echo ""
    
    # Kiểm tra Kubernetes cluster
    if kubectl cluster-info &> /dev/null; then
        echo "✓ Kubernetes Cluster đang chạy"
        kubectl get nodes
    else
        echo "✗ Kubernetes Cluster chưa sẵn sàng hoặc chưa được khởi tạo"
    fi
}

# Tạo script khởi động nhanh
create_quick_start_script() {
    log_info "Tạo script khởi động nhanh..."
    
    cat > ~/start-hadoop-ecosystem.sh << 'EOF'
#!/bin/bash

echo "Khởi động Hadoop E-commerce Ecosystem..."

# Kiểm tra cluster
kubectl cluster-info

# Chuyển đến thư mục dự án
cd ~/hadoop-ecommerce-ecosystem || exit

# Deploy hệ thống
echo "Triển khai hệ thống..."
make deploy

echo "Hệ thống đã sẵn sàng!"
echo ""
echo "Truy cập Web UIs:"
echo "- Hadoop NameNode: make forward-namenode (http://localhost:9870)"
echo "- Spark Master: make forward-spark (http://localhost:8080)"
echo "- YARN ResourceManager: kubectl port-forward -n hadoop-ecosystem svc/yarn-resourcemanager 8088:8088"
echo "- Grafana: make forward-grafana (http://localhost:3000)"
EOF
    
    chmod +x ~/start-hadoop-ecosystem.sh
    log_success "Script khởi động nhanh đã được tạo: ~/start-hadoop-ecosystem.sh"
}

# Hàm chính
main() {
    echo "=========================================="
    echo "CÀI ĐẶT HADOOP E-COMMERCE ECOSYSTEM"
    echo "=========================================="
    echo ""
    
    check_os
    update_system
    install_docker
    install_docker_compose
    install_kubernetes
    install_helm
    install_additional_tools
    configure_firewall
    init_kubernetes_cluster
    verify_installation
    create_quick_start_script
    
    echo ""
    echo "=========================================="
    echo "CÀI ĐẶT HOÀN TẤT!"
    echo "=========================================="
    echo ""
    echo "Các bước tiếp theo:"
    echo "1. Đăng xuất và đăng nhập lại để sử dụng Docker không cần sudo"
    echo "2. Nếu đây là worker node, chạy lệnh join từ master"
    echo "3. Clone repository và triển khai hệ thống:"
    echo "   git clone <repository-url>"
    echo "   cd hadoop-ecommerce-ecosystem"
    echo "   make deploy"
    echo ""
    echo "Hoặc chạy script nhanh: ~/start-hadoop-ecosystem.sh"
    echo ""
    
    log_success "Cài đặt thành công tất cả các ứng dụng cần thiết!"
}

# Chạy hàm chính
main "$@"