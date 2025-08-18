#!/bin/bash

set -e

echo "Installing Kubernetes on Ubuntu..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root"
   exit 1
fi

# Check Ubuntu version
check_ubuntu_version() {
    if ! lsb_release -d | grep -q "Ubuntu"; then
        log_error "This script is designed for Ubuntu. Detected: $(lsb_release -d)"
        exit 1
    fi
    log_info "Ubuntu detected: $(lsb_release -d)"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    sudo apt-get update -y
    sudo apt-get upgrade -y
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Configure Docker daemon
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
    
    log_info "Docker installed successfully"
}

# Install kubeadm, kubelet, kubectl
install_kubernetes_tools() {
    log_info "Installing Kubernetes tools..."
    
    # Add Kubernetes signing key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add Kubernetes repository
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Install Kubernetes tools
    sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    
    log_info "Kubernetes tools installed successfully"
}

# Configure system for Kubernetes
configure_system() {
    log_info "Configuring system for Kubernetes..."
    
    # Disable swap
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Load required kernel modules
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    # Set sysctl parameters
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sudo sysctl --system
    
    log_info "System configured for Kubernetes"
}

# Initialize Kubernetes cluster (master node only)
init_cluster() {
    read -p "Is this the master node? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Initializing Kubernetes cluster..."
        
        # Initialize cluster
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16
        
        # Configure kubectl for current user
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        # Install Flannel CNI
        kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        
        # Allow scheduling on master node (for single-node testing)
        kubectl taint nodes --all node-role.kubernetes.io/control-plane-
        
        log_info "Kubernetes cluster initialized successfully!"
        log_info "To add worker nodes, run the join command shown above on each worker node."
        
        # Display join command
        echo ""
        echo "=== Join Command for Worker Nodes ==="
        sudo kubeadm token create --print-join-command
        echo ""
    else
        log_info "Skipping cluster initialization. Run 'kubeadm join' command on this worker node."
    fi
}

# Install additional tools
install_additional_tools() {
    log_info "Installing additional tools..."
    
    # Install Helm
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update -y
    sudo apt-get install -y helm
    
    # Install k9s (Kubernetes CLI)
    curl -sS https://webinstall.dev/k9s | bash
    
    log_info "Additional tools installed successfully"
}

# Main installation function
main() {
    log_info "Starting Kubernetes installation on Ubuntu..."
    
    check_ubuntu_version
    update_system
    install_docker
    configure_system
    install_kubernetes_tools
    init_cluster
    install_additional_tools
    
    log_info "Kubernetes installation completed!"
    log_info "Please log out and log back in to use Docker without sudo."
    log_info "Run 'kubectl get nodes' to check cluster status."
}

# Run main function
main "$@"