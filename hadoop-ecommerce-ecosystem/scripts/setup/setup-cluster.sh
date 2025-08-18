#!/bin/bash

set -e

echo "Setting up Hadoop E-commerce Ecosystem Cluster..."

# Load environment variables
source .env

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

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    log_info "kubectl is installed"
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    log_info "Kubernetes cluster is accessible"
}

# Label nodes for scheduling
label_nodes() {
    log_info "Labeling nodes for scheduling..."
    
    # Get all nodes
    NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    
    if [ ${#NODES[@]} -lt 3 ]; then
        log_error "Need at least 3 nodes for this setup (1 master, 2 workers)"
        exit 1
    fi
    
    # Label first node as master
    kubectl label node ${NODES[0]} node-role=master --overwrite
    log_info "Labeled ${NODES[0]} as master node"
    
    # Label remaining nodes as workers
    for i in $(seq 1 $((${#NODES[@]}-1))); do
        kubectl label node ${NODES[$i]} node-role=worker --overwrite
        log_info "Labeled ${NODES[$i]} as worker node"
    done
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    kubectl apply -f kubernetes/namespace.yaml
}

# Setup storage
setup_storage() {
    log_info "Setting up storage..."
    
    # Create directories on nodes
    for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
        kubectl debug node/$node -it --image=busybox -- mkdir -p /host/data/hadoop/namenode /host/data/hadoop/datanode1 /host/data/hadoop/datanode2 /host/data/zookeeper /host/data/kafka /host/data/postgres
    done
    
    kubectl apply -f kubernetes/storage/
}

# Setup RBAC
setup_rbac() {
    log_info "Setting up RBAC..."
    kubectl apply -f kubernetes/rbac/
}

# Apply ConfigMaps
apply_configmaps() {
    log_info "Applying ConfigMaps..."
    kubectl apply -f kubernetes/configmaps/
}

# Apply Secrets
apply_secrets() {
    log_info "Applying Secrets..."
    kubectl apply -f kubernetes/secrets/
}

# Main setup function
main() {
    log_info "Starting Hadoop E-commerce Ecosystem setup..."
    
    check_kubectl
    check_cluster
    label_nodes
    create_namespace
    setup_storage
    setup_rbac
    apply_configmaps
    apply_secrets
    
    log_info "Cluster setup completed successfully!"
    log_info "You can now deploy services using: make deploy"
    
    # Display cluster information
    echo ""
    echo "=== Cluster Information ==="
    kubectl get nodes -o wide
    echo ""
    kubectl get namespaces
    echo ""
    log_info "Setup completed. Ready for deployment!"
}

# Run main function
main "$@"