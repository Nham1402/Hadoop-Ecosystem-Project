#!/bin/bash

set -e

echo "Khắc phục lỗi kubectl và kiểm tra Kubernetes cluster..."

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

# Kiểm tra trạng thái hiện tại
check_current_status() {
    echo "=========================================="
    echo "KIỂM TRA TRẠNG THÁI HIỆN TẠI"
    echo "=========================================="
    
    # Kiểm tra kubectl
    if command -v kubectl &> /dev/null; then
        log_success "kubectl đã được cài đặt: $(kubectl version --client --short 2>/dev/null || echo 'Version check failed')"
    else
        log_error "kubectl chưa được cài đặt"
        return 1
    fi
    
    # Kiểm tra kubeadm
    if command -v kubeadm &> /dev/null; then
        log_success "kubeadm đã được cài đặt: $(kubeadm version -o short 2>/dev/null || echo 'Version check failed')"
    else
        log_error "kubeadm chưa được cài đặt"
        return 1
    fi
    
    # Kiểm tra kubelet
    if systemctl is-active --quiet kubelet; then
        log_success "kubelet đang chạy"
    else
        log_warn "kubelet không chạy hoặc chưa được cài đặt"
        sudo systemctl status kubelet --no-pager -l || true
    fi
    
    # Kiểm tra Docker
    if systemctl is-active --quiet docker; then
        log_success "Docker đang chạy"
    else
        log_error "Docker không chạy"
        return 1
    fi
    
    # Kiểm tra file kubeconfig
    if [ -f ~/.kube/config ]; then
        log_info "File kubeconfig tồn tại tại: ~/.kube/config"
        ls -la ~/.kube/config
    else
        log_warn "File kubeconfig không tồn tại"
    fi
    
    # Kiểm tra admin config
    if [ -f /etc/kubernetes/admin.conf ]; then
        log_info "File admin.conf tồn tại"
        sudo ls -la /etc/kubernetes/admin.conf
    else
        log_warn "File admin.conf không tồn tại - cluster chưa được khởi tạo"
    fi
}

# Khắc phục cấu hình kubectl
fix_kubectl_config() {
    log_info "Khắc phục cấu hình kubectl..."
    
    if [ -f /etc/kubernetes/admin.conf ]; then
        log_info "Sao chép admin.conf để cấu hình kubectl..."
        
        # Tạo thư mục .kube
        mkdir -p ~/.kube
        
        # Sao chép config
        sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
        sudo chown $(id -u):$(id -g) ~/.kube/config
        
        log_success "Đã cấu hình kubectl từ admin.conf"
        
        # Kiểm tra kết nối
        if kubectl cluster-info &> /dev/null; then
            log_success "kubectl đã kết nối thành công với cluster"
            return 0
        else
            log_warn "kubectl vẫn không thể kết nối"
        fi
    else
        log_warn "File admin.conf không tồn tại - cần khởi tạo cluster"
        return 1
    fi
}

# Kiểm tra cluster đã được khởi tạo chưa
check_cluster_init() {
    log_info "Kiểm tra trạng thái cluster..."
    
    # Kiểm tra các thành phần Kubernetes
    if sudo systemctl is-active --quiet kubelet; then
        log_info "kubelet đang chạy"
    else
        log_warn "kubelet không chạy"
        sudo systemctl start kubelet || true
    fi
    
    # Kiểm tra container runtime
    if sudo crictl ps &> /dev/null; then
        log_info "Container runtime hoạt động"
        RUNNING_CONTAINERS=$(sudo crictl ps -q | wc -l)
        log_info "Số container đang chạy: $RUNNING_CONTAINERS"
    else
        log_warn "Container runtime không hoạt động hoặc chưa cấu hình"
    fi
    
    # Kiểm tra etcd
    if sudo systemctl is-active --quiet etcd 2>/dev/null; then
        log_info "etcd đang chạy"
    else
        log_info "etcd không chạy như service (có thể chạy trong container)"
    fi
}

# Khởi tạo cluster nếu chưa có
init_cluster_if_needed() {
    if [ ! -f /etc/kubernetes/admin.conf ]; then
        echo ""
        echo "=========================================="
        echo "CLUSTER CHƯA ĐƯỢC KHỞI TẠO"
        echo "=========================================="
        
        read -p "Bạn có muốn khởi tạo Kubernetes cluster ngay bây giờ? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Khởi tạo Kubernetes cluster..."
            
            # Lấy IP của máy
            MASTER_IP=$(hostname -I | awk '{print $1}')
            log_info "Sử dụng IP Master: $MASTER_IP"
            
            # Khởi tạo cluster
            sudo kubeadm init \
                --pod-network-cidr=10.244.0.0/16 \
                --apiserver-advertise-address=$MASTER_IP \
                --node-name=$(hostname)
            
            if [ $? -eq 0 ]; then
                log_success "Cluster đã được khởi tạo thành công!"
                
                # Cấu hình kubectl
                fix_kubectl_config
                
                # Cài đặt CNI (Flannel)
                log_info "Cài đặt Flannel CNI..."
                kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
                
                # Cho phép scheduling trên master (cho single-node testing)
                log_info "Cho phép scheduling trên master node..."
                kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
                
                # Hiển thị join command
                echo ""
                echo "=========================================="
                echo "LỆNH JOIN CHO WORKER NODES:"
                echo "=========================================="
                sudo kubeadm token create --print-join-command
                echo "=========================================="
                
            else
                log_error "Khởi tạo cluster thất bại!"
                return 1
            fi
        else
            log_info "Bỏ qua khởi tạo cluster"
            return 1
        fi
    else
        log_info "Cluster đã được khởi tạo trước đó"
        fix_kubectl_config
    fi
}

# Reset cluster nếu cần
reset_cluster_if_needed() {
    echo ""
    read -p "Cluster có vẻ bị lỗi. Bạn có muốn reset và khởi tạo lại? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Đang reset cluster..."
        
        # Reset kubeadm
        sudo kubeadm reset -f
        
        # Dọn dẹp
        sudo rm -rf ~/.kube
        sudo rm -rf /etc/kubernetes/
        sudo rm -rf /var/lib/etcd/
        
        # Restart services
        sudo systemctl restart kubelet
        sudo systemctl restart docker
        
        log_info "Cluster đã được reset. Khởi tạo lại..."
        init_cluster_if_needed
    fi
}

# Kiểm tra và sửa lỗi network
fix_network_issues() {
    log_info "Kiểm tra và sửa lỗi network..."
    
    # Kiểm tra swap
    if swapon --show | grep -q "/"; then
        log_warn "Swap vẫn đang bật. Đang tắt swap..."
        sudo swapoff -a
        sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    fi
    
    # Kiểm tra kernel modules
    if ! lsmod | grep -q br_netfilter; then
        log_info "Load kernel module br_netfilter..."
        sudo modprobe br_netfilter
    fi
    
    if ! lsmod | grep -q overlay; then
        log_info "Load kernel module overlay..."
        sudo modprobe overlay
    fi
    
    # Kiểm tra sysctl settings
    if [ "$(sysctl -n net.bridge.bridge-nf-call-iptables)" != "1" ]; then
        log_info "Cấu hình sysctl settings..."
        echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee -a /etc/sysctl.conf
        echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.conf
        echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
        sudo sysctl --system
    fi
}

# Kiểm tra ports
check_ports() {
    log_info "Kiểm tra các ports cần thiết..."
    
    REQUIRED_PORTS=(6443 2379 2380 10250 10259 10257)
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            log_info "Port $port đang được sử dụng"
        else
            log_warn "Port $port không được sử dụng"
        fi
    done
}

# Hiển thị hướng dẫn tiếp theo
show_next_steps() {
    echo ""
    echo "=========================================="
    echo "CÁC BƯỚC TIẾP THEO"
    echo "=========================================="
    
    if kubectl get nodes &> /dev/null; then
        log_success "kubectl đã hoạt động! Các bước tiếp theo:"
        echo ""
        echo "1. Kiểm tra nodes:"
        echo "   kubectl get nodes -o wide"
        echo ""
        echo "2. Kiểm tra pods hệ thống:"
        echo "   kubectl get pods -n kube-system"
        echo ""
        echo "3. Triển khai Hadoop ecosystem:"
        echo "   make deploy"
        echo ""
        echo "4. Nếu cần thêm worker nodes, sử dụng lệnh join:"
        sudo kubeadm token create --print-join-command 2>/dev/null || echo "   (Chạy 'sudo kubeadm token create --print-join-command' để lấy lệnh join)"
        
    else
        log_error "kubectl vẫn chưa hoạt động. Các tùy chọn:"
        echo ""
        echo "1. Kiểm tra logs kubelet:"
        echo "   sudo journalctl -xeu kubelet"
        echo ""
        echo "2. Reset và khởi tạo lại:"
        echo "   sudo kubeadm reset -f"
        echo "   sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
        echo ""
        echo "3. Kiểm tra Docker:"
        echo "   sudo systemctl status docker"
    fi
}

# Test kubectl sau khi sửa
test_kubectl() {
    log_info "Test kubectl sau khi khắc phục..."
    
    echo "Thử lệnh kubectl get nodes..."
    if kubectl get nodes; then
        log_success "kubectl hoạt động bình thường!"
        
        echo ""
        echo "Thông tin cluster:"
        kubectl cluster-info
        
        echo ""
        echo "Pods hệ thống:"
        kubectl get pods -n kube-system
        
        return 0
    else
        log_error "kubectl vẫn không hoạt động"
        return 1
    fi
}

# Hàm chính
main() {
    echo "=========================================="
    echo "KHẮC PHỤC LỖI KUBECTL"
    echo "=========================================="
    
    # Kiểm tra trạng thái hiện tại
    if ! check_current_status; then
        log_error "Một số thành phần cần thiết chưa được cài đặt"
        echo "Chạy script cài đặt trước: ./scripts/setup/install-prerequisites.sh"
        exit 1
    fi
    
    # Sửa lỗi network
    fix_network_issues
    
    # Kiểm tra ports
    check_ports
    
    # Kiểm tra cluster
    check_cluster_init
    
    # Thử sửa kubectl config trước
    if fix_kubectl_config; then
        log_success "Đã khắc phục kubectl config"
    else
        # Nếu không có admin.conf, khởi tạo cluster
        if ! init_cluster_if_needed; then
            # Nếu không muốn khởi tạo, thử reset
            reset_cluster_if_needed
        fi
    fi
    
    # Test kubectl
    if test_kubectl; then
        show_next_steps
    else
        log_error "Không thể khắc phục lỗi kubectl"
        echo ""
        echo "Hãy thử các bước thủ công:"
        echo "1. sudo kubeadm reset -f"
        echo "2. sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
        echo "3. mkdir -p ~/.kube && sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config"
        echo "4. sudo chown \$(id -u):\$(id -g) ~/.kube/config"
        exit 1
    fi
}

# Chạy hàm chính
main "$@"