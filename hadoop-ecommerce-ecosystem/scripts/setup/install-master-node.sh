#!/bin/bash

set -e

echo "Cài đặt và cấu hình Master Node cho Hadoop Ecosystem..."

# Màu sắc
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[CẢNH BÁO]${NC} $1"; }
log_error() { echo -e "${RED}[LỖI]${NC} $1"; }

# Cài đặt prerequisites
install_prerequisites() {
    log_info "Cài đặt các ứng dụng cần thiết..."
    chmod +x scripts/setup/install-prerequisites.sh
    ./scripts/setup/install-prerequisites.sh
}

# Cấu hình Master Node với tài nguyên 6GB RAM, 3 CPU
configure_master_node() {
    log_info "Cấu hình Master Node (6GB RAM, 3 CPU cores)..."
    
    # Gắn nhãn cho master node
    kubectl label node $(hostname) node-role=master --overwrite
    kubectl label node $(hostname) hadoop-role=master --overwrite
    
    # Tạo taint để chỉ master components chạy trên master
    kubectl taint nodes $(hostname) node-role.kubernetes.io/master=true:NoSchedule --overwrite || true
    
    log_info "Master node đã được cấu hình với nhãn: node-role=master"
}

# Tạo namespace và cấu hình tài nguyên
setup_namespace_and_resources() {
    log_info "Tạo namespace và cấu hình tài nguyên..."
    
    # Tạo namespace
    kubectl create namespace hadoop-ecosystem --dry-run=client -o yaml | kubectl apply -f -
    
    # Tạo ResourceQuota cho master node
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: master-node-quota
  namespace: hadoop-ecosystem
spec:
  hard:
    requests.cpu: "3"
    requests.memory: "6Gi"
    limits.cpu: "3"
    limits.memory: "6Gi"
    pods: "20"
EOF
    
    log_info "Namespace và ResourceQuota đã được tạo"
}

# Cài đặt storage cho master node
setup_master_storage() {
    log_info "Cài đặt storage cho Master Node..."
    
    # Tạo thư mục lưu trữ
    sudo mkdir -p /data/hadoop/{namenode,resourcemanager,spark-master}
    sudo mkdir -p /data/{zookeeper,kafka,postgres,prometheus,grafana}
    sudo chown -R $(whoami):$(whoami) /data
    
    # Tạo PersistentVolumes cho master components
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: master-namenode-pv
  labels:
    type: local
    component: namenode
    node-role: master
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data/hadoop/namenode
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $(hostname)
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: master-zookeeper-pv
  labels:
    type: local
    component: zookeeper
    node-role: master
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /data/zookeeper
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $(hostname)
EOF
    
    log_info "Storage cho Master Node đã được cấu hình"
}

# Deploy master components
deploy_master_components() {
    log_info "Triển khai các thành phần Master..."
    
    # Apply ConfigMaps
    kubectl apply -f kubernetes/configmaps/
    
    # Deploy Zookeeper (chạy trên master)
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zookeeper
  namespace: hadoop-ecosystem
  labels:
    app: zookeeper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zookeeper
  template:
    metadata:
      labels:
        app: zookeeper
    spec:
      nodeSelector:
        node-role: master
      containers:
      - name: zookeeper
        image: confluentinc/cp-zookeeper:7.4.0
        ports:
        - containerPort: 2181
        env:
        - name: ZOOKEEPER_CLIENT_PORT
          value: "2181"
        - name: ZOOKEEPER_TICK_TIME
          value: "2000"
        resources:
          requests:
            memory: "512Mi"
            cpu: "0.5"
          limits:
            memory: "1Gi"
            cpu: "1"
        volumeMounts:
        - name: zookeeper-data
          mountPath: /var/lib/zookeeper
      volumes:
      - name: zookeeper-data
        persistentVolumeClaim:
          claimName: zookeeper-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: zookeeper-pvc
  namespace: hadoop-ecosystem
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-storage
  resources:
    requests:
      storage: 10Gi
  selector:
    matchLabels:
      component: zookeeper
      node-role: master
---
apiVersion: v1
kind: Service
metadata:
  name: zookeeper
  namespace: hadoop-ecosystem
spec:
  ports:
  - port: 2181
    targetPort: 2181
  selector:
    app: zookeeper
EOF
    
    log_info "Zookeeper đã được triển khai trên Master Node"
    
    # Chờ Zookeeper sẵn sàng
    log_info "Chờ Zookeeper khởi động..."
    kubectl wait --for=condition=available --timeout=300s deployment/zookeeper -n hadoop-ecosystem
}

# Hiển thị thông tin master node
show_master_info() {
    echo ""
    echo "=========================================="
    echo "THÔNG TIN MASTER NODE"
    echo "=========================================="
    
    # Thông tin node
    echo "Node Information:"
    kubectl get nodes $(hostname) -o wide
    
    echo ""
    echo "Node Labels:"
    kubectl get nodes $(hostname) --show-labels
    
    echo ""
    echo "Resource Quota:"
    kubectl describe resourcequota master-node-quota -n hadoop-ecosystem
    
    echo ""
    echo "Pods trên Master Node:"
    kubectl get pods -n hadoop-ecosystem -o wide --field-selector spec.nodeName=$(hostname)
    
    echo ""
    echo "Services:"
    kubectl get services -n hadoop-ecosystem
}

# Tạo script join cho worker nodes
create_join_script() {
    log_info "Tạo script join cho Worker Nodes..."
    
    # Tạo join command
    JOIN_CMD=$(sudo kubeadm token create --print-join-command)
    
    cat > ~/join-worker-nodes.sh << EOF
#!/bin/bash

echo "Script này sẽ được chạy trên các Worker Nodes để tham gia cluster"
echo ""
echo "Trước khi chạy script này trên worker node, hãy đảm bảo:"
echo "1. Đã cài đặt Docker và Kubernetes tools"
echo "2. Đã cấu hình hệ thống (disable swap, configure kernel modules)"
echo ""
echo "Lệnh join (chạy với sudo trên worker nodes):"
echo "----------------------------------------"
echo "$JOIN_CMD"
echo "----------------------------------------"
echo ""
echo "Sau khi join thành công, chạy lệnh sau để gắn nhãn worker:"
echo "kubectl label node <worker-node-name> node-role=worker"
echo "kubectl label node <worker-node-name> hadoop-role=worker"
EOF
    
    chmod +x ~/join-worker-nodes.sh
    
    echo ""
    echo "=========================================="
    echo "LỆNH JOIN CHO WORKER NODES"
    echo "=========================================="
    echo "$JOIN_CMD"
    echo "=========================================="
    echo ""
    echo "Script join đã được lưu tại: ~/join-worker-nodes.sh"
}

# Hàm chính
main() {
    echo "=========================================="
    echo "CÀI ĐẶT MASTER NODE"
    echo "Cấu hình: 6GB RAM, 3 CPU Cores"
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
    echo "  - RAM: ${TOTAL_MEM}GB (yêu cầu: ≥6GB)"
    echo "  - CPU: ${TOTAL_CPU} cores (yêu cầu: ≥3 cores)"
    
    if [ "$TOTAL_MEM" -lt 6 ] || [ "$TOTAL_CPU" -lt 3 ]; then
        log_warn "Tài nguyên hệ thống không đủ yêu cầu!"
        read -p "Bạn có muốn tiếp tục? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Thực hiện cài đặt
    install_prerequisites
    configure_master_node
    setup_namespace_and_resources
    setup_master_storage
    deploy_master_components
    show_master_info
    create_join_script
    
    echo ""
    echo "=========================================="
    echo "CÀI ĐẶT MASTER NODE HOÀN TẤT!"
    echo "=========================================="
    echo ""
    echo "Các bước tiếp theo:"
    echo "1. Chạy script join trên các Worker Nodes"
    echo "2. Kiểm tra cluster: kubectl get nodes"
    echo "3. Triển khai Hadoop ecosystem: make deploy"
    echo ""
    echo "Master Node đã sẵn sàng với cấu hình:"
    echo "- 6GB RAM, 3 CPU cores"
    echo "- Zookeeper đang chạy"
    echo "- Storage đã được cấu hình"
    echo "- Namespace hadoop-ecosystem đã được tạo"
}

# Chạy hàm chính
main "$@"