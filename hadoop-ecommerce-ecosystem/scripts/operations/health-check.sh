#!/bin/bash

set -e

echo "Performing Hadoop E-commerce Ecosystem Health Check..."

# Load environment variables
source .env 2>/dev/null || echo "Warning: .env file not found"

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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Set default namespace if not provided
NAMESPACE=${NAMESPACE:-hadoop-ecosystem}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Kubernetes cluster is accessible"
}

# Check namespace
check_namespace() {
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_success "Namespace '$NAMESPACE' exists"
    else
        log_error "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
}

# Check pod status
check_pods() {
    log_info "Checking pod status..."
    
    # Get all pods in namespace
    PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$PODS" ]; then
        log_warn "No pods found in namespace $NAMESPACE"
        return 1
    fi
    
    # Check each pod
    for pod in $PODS; do
        STATUS=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
        READY=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}')
        
        if [ "$STATUS" = "Running" ] && [ "$READY" = "true" ]; then
            log_success "Pod $pod is running and ready"
        else
            log_error "Pod $pod is not ready (Status: $STATUS, Ready: $READY)"
            kubectl describe pod $pod -n $NAMESPACE | tail -10
        fi
    done
}

# Check services
check_services() {
    log_info "Checking services..."
    
    SERVICES=$(kubectl get services -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    
    for service in $SERVICES; do
        ENDPOINTS=$(kubectl get endpoints $service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}')
        
        if [ -n "$ENDPOINTS" ]; then
            log_success "Service $service has endpoints: $ENDPOINTS"
        else
            log_warn "Service $service has no endpoints"
        fi
    done
}

# Check Hadoop NameNode
check_namenode() {
    log_info "Checking Hadoop NameNode..."
    
    if kubectl get pod -n $NAMESPACE -l component=namenode | grep -q Running; then
        # Port forward to check web UI
        kubectl port-forward -n $NAMESPACE svc/hadoop-namenode 9870:9870 &
        PF_PID=$!
        sleep 5
        
        if curl -s http://localhost:9870 > /dev/null; then
            log_success "NameNode web UI is accessible"
        else
            log_error "NameNode web UI is not accessible"
        fi
        
        kill $PF_PID 2>/dev/null || true
    else
        log_error "NameNode pod is not running"
    fi
}

# Check Spark Master
check_spark_master() {
    log_info "Checking Spark Master..."
    
    if kubectl get pod -n $NAMESPACE -l component=master,app=spark | grep -q Running; then
        # Port forward to check web UI
        kubectl port-forward -n $NAMESPACE svc/spark-master 8080:8080 &
        PF_PID=$!
        sleep 5
        
        if curl -s http://localhost:8080 > /dev/null; then
            log_success "Spark Master web UI is accessible"
        else
            log_error "Spark Master web UI is not accessible"
        fi
        
        kill $PF_PID 2>/dev/null || true
    else
        log_error "Spark Master pod is not running"
    fi
}

# Check HDFS health
check_hdfs_health() {
    log_info "Checking HDFS health..."
    
    # Run fsck command in namenode pod
    NAMENODE_POD=$(kubectl get pods -n $NAMESPACE -l component=namenode -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$NAMENODE_POD" ]; then
        FSCK_OUTPUT=$(kubectl exec -n $NAMESPACE $NAMENODE_POD -- hdfs fsck / 2>/dev/null | tail -5)
        
        if echo "$FSCK_OUTPUT" | grep -q "The filesystem under path '/' is HEALTHY"; then
            log_success "HDFS filesystem is healthy"
        else
            log_warn "HDFS filesystem health check inconclusive"
            echo "$FSCK_OUTPUT"
        fi
    else
        log_error "Cannot find NameNode pod for HDFS health check"
    fi
}

# Check YARN health
check_yarn_health() {
    log_info "Checking YARN health..."
    
    RM_POD=$(kubectl get pods -n $NAMESPACE -l component=resourcemanager -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$RM_POD" ]; then
        NODE_COUNT=$(kubectl exec -n $NAMESPACE $RM_POD -- yarn node -list 2>/dev/null | grep -c "RUNNING" || echo "0")
        
        if [ "$NODE_COUNT" -gt 0 ]; then
            log_success "YARN has $NODE_COUNT running nodes"
        else
            log_warn "No YARN nodes are running"
        fi
    else
        log_error "Cannot find ResourceManager pod for YARN health check"
    fi
}

# Check resource usage
check_resource_usage() {
    log_info "Checking resource usage..."
    
    # Get node resource usage
    kubectl top nodes 2>/dev/null || log_warn "Metrics server not available for node metrics"
    
    # Get pod resource usage
    kubectl top pods -n $NAMESPACE 2>/dev/null || log_warn "Metrics server not available for pod metrics"
}

# Check persistent volumes
check_persistent_volumes() {
    log_info "Checking persistent volumes..."
    
    PVS=$(kubectl get pv -o jsonpath='{.items[*].metadata.name}')
    
    for pv in $PVS; do
        STATUS=$(kubectl get pv $pv -o jsonpath='{.status.phase}')
        
        if [ "$STATUS" = "Bound" ]; then
            log_success "PV $pv is bound"
        else
            log_warn "PV $pv status: $STATUS"
        fi
    done
}

# Generate health report
generate_report() {
    log_info "Generating health report..."
    
    REPORT_FILE="/tmp/hadoop-ecosystem-health-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== Hadoop E-commerce Ecosystem Health Report ==="
        echo "Generated: $(date)"
        echo "Namespace: $NAMESPACE"
        echo ""
        
        echo "=== Pod Status ==="
        kubectl get pods -n $NAMESPACE -o wide
        echo ""
        
        echo "=== Service Status ==="
        kubectl get services -n $NAMESPACE
        echo ""
        
        echo "=== Persistent Volume Status ==="
        kubectl get pv
        echo ""
        
        echo "=== Node Status ==="
        kubectl get nodes -o wide
        echo ""
        
        echo "=== Events (Last 10) ==="
        kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
        
    } > $REPORT_FILE
    
    log_success "Health report generated: $REPORT_FILE"
}

# Main health check function
main() {
    log_info "Starting comprehensive health check..."
    
    check_kubectl
    check_namespace || exit 1
    check_pods
    check_services
    check_namenode
    check_spark_master
    check_hdfs_health
    check_yarn_health
    check_resource_usage
    check_persistent_volumes
    generate_report
    
    log_success "Health check completed!"
    echo ""
    echo "=== Summary ==="
    kubectl get pods -n $NAMESPACE
}

# Run main function
main "$@"