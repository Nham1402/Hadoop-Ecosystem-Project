# HƯỚNG DẪN CÀI ĐẶT HADOOP E-COMMERCE ECOSYSTEM

## Tổng quan hệ thống

**Cấu hình cluster:**
- 1 Master Node: 6GB RAM, 3 CPU cores
- 2 Worker Nodes: mỗi node 4GB RAM, 2 CPU cores
- Tổng tài nguyên: 14GB RAM, 7 CPU cores

**Các thành phần chính:**
- Hadoop HDFS (lưu trữ phân tán)
- Apache Spark (xử lý batch và stream)
- Apache Kafka (streaming real-time)
- Apache Hive (data warehouse)
- Apache HBase (NoSQL database)
- Apache Airflow (workflow orchestration)
- Monitoring (Prometheus + Grafana)

## BƯỚC 1: CÀI ĐẶT MASTER NODE

### Trên máy Master (6GB RAM, 3 CPU):

```bash
# 1. Clone repository
git clone <repository-url>
cd hadoop-ecommerce-ecosystem

# 2. Cấp quyền thực thi cho scripts
chmod +x scripts/setup/*.sh

# 3. Cài đặt Master Node
./scripts/setup/install-master-node.sh
```

Script sẽ thực hiện:
- Cài đặt Docker, Kubernetes, Helm
- Khởi tạo Kubernetes cluster
- Cấu hình Master Node với tài nguyên phù hợp
- Triển khai Zookeeper
- Tạo namespace và storage

### Sau khi cài đặt Master Node:

```bash
# Kiểm tra cluster
kubectl get nodes
kubectl get pods -n hadoop-ecosystem

# Lấy lệnh join cho Worker Nodes
sudo kubeadm token create --print-join-command
```

## BƯỚC 2: CÀI ĐẶT WORKER NODES

### Trên mỗi máy Worker (4GB RAM, 2 CPU):

```bash
# 1. Clone repository
git clone <repository-url>
cd hadoop-ecommerce-ecosystem

# 2. Cài đặt Worker Node (thay <JOIN_COMMAND> bằng lệnh từ Master)
./scripts/setup/install-worker-node.sh "<JOIN_COMMAND>"

# Ví dụ:
./scripts/setup/install-worker-node.sh "sudo kubeadm join 192.168.1.100:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:..."
```

### Từ Master Node, cấu hình Worker Nodes:

```bash
# Gắn nhãn cho Worker Nodes
kubectl label node worker-1 node-role=worker
kubectl label node worker-2 node-role=worker

# Kiểm tra tất cả nodes
kubectl get nodes -o wide
```

## BƯỚC 3: TRIỂN KHAI HỆ THỐNG

### Từ Master Node:

```bash
# 1. Build Docker images
make build

# 2. Triển khai toàn bộ hệ thống
make deploy

# Hoặc triển khai từng bước:
./scripts/deploy/deploy-all.sh
```

### Kiểm tra triển khai:

```bash
# Kiểm tra tất cả pods
kubectl get pods -n hadoop-ecosystem

# Kiểm tra services
kubectl get services -n hadoop-ecosystem

# Chạy health check
./scripts/operations/health-check.sh
```

## BƯỚC 4: TRUY CẬP WEB UIs

### Sử dụng Port Forwarding:

```bash
# Hadoop NameNode (http://localhost:9870)
kubectl port-forward -n hadoop-ecosystem svc/hadoop-namenode 9870:9870

# Spark Master (http://localhost:8080)
kubectl port-forward -n hadoop-ecosystem svc/spark-master 8080:8080

# YARN ResourceManager (http://localhost:8088)
kubectl port-forward -n hadoop-ecosystem svc/yarn-resourcemanager 8088:8088

# Grafana Monitoring (http://localhost:3000)
kubectl port-forward -n hadoop-ecosystem svc/grafana 3000:3000

# Airflow (http://localhost:8080)
kubectl port-forward -n hadoop-ecosystem svc/airflow-webserver 8080:8080
```

### Hoặc sử dụng Makefile:

```bash
make forward-namenode    # Hadoop UI
make forward-spark       # Spark UI
make forward-grafana     # Monitoring UI
```

### Truy cập qua NodePort (từ bên ngoài):

- Hadoop NameNode: `http://<master-ip>:30870`
- YARN ResourceManager: `http://<master-ip>:30088`
- Spark Master: `http://<master-ip>:30080`

## BƯỚC 5: LOAD DỮ LIỆU MẪU

```bash
# Load dữ liệu e-commerce mẫu
make load-data

# Hoặc chạy manual:
./scripts/data/sample-data-loader.sh
```

## BƯỚC 6: CHẠY CÁC JOB MẪU

### Spark Job - Báo cáo bán hàng hàng ngày:

```bash
# Submit job qua kubectl
kubectl exec -n hadoop-ecosystem deployment/spark-master -- \
  spark-submit \
  --master spark://spark-master:7077 \
  --deploy-mode client \
  /opt/spark/jobs/batch-processing/daily_sales_report.py
```

### Airflow DAG - Pipeline ETL tự động:

1. Truy cập Airflow UI: `http://localhost:8080`
2. Enable DAG `daily_etl_pipeline`
3. Trigger manual hoặc chờ schedule

## GIÁM SÁT HỆ THỐNG

### Prometheus Metrics:

```bash
# Port forward Prometheus
kubectl port-forward -n hadoop-ecosystem svc/prometheus 9090:9090
# Truy cập: http://localhost:9090
```

### Grafana Dashboards:

```bash
# Port forward Grafana
kubectl port-forward -n hadoop-ecosystem svc/grafana 3000:3000
# Truy cập: http://localhost:3000 (admin/admin)
```

### Kiểm tra logs:

```bash
# Logs của NameNode
kubectl logs -f deployment/hadoop-namenode -n hadoop-ecosystem

# Logs của Spark Master
kubectl logs -f deployment/spark-master -n hadoop-ecosystem

# Logs của tất cả Hadoop components
kubectl logs -f -l app=hadoop -n hadoop-ecosystem
```

## SCALING VÀ QUẢN LÝ

### Scale Worker Nodes:

```bash
# Scale DataNodes
kubectl scale statefulset hadoop-datanode --replicas=3 -n hadoop-ecosystem

# Scale Spark Workers
kubectl scale statefulset spark-worker --replicas=3 -n hadoop-ecosystem
```

### Backup và Restore:

```bash
# Backup dữ liệu
./scripts/operations/backup-data.sh

# Restore dữ liệu
./scripts/operations/restore-data.sh
```

### Health Check:

```bash
# Kiểm tra sức khỏe toàn hệ thống
./scripts/operations/health-check.sh
```

## TROUBLESHOOTING

### Vấn đề thường gặp:

1. **Pods bị Pending:**
   ```bash
   kubectl describe pod <pod-name> -n hadoop-ecosystem
   # Kiểm tra resource constraints hoặc node selector
   ```

2. **NameNode không khởi động:**
   ```bash
   kubectl logs deployment/hadoop-namenode -n hadoop-ecosystem
   # Kiểm tra storage mount và permissions
   ```

3. **Worker Nodes không join được:**
   ```bash
   # Trên worker node, kiểm tra:
   sudo systemctl status kubelet
   sudo journalctl -xeu kubelet
   ```

### Kiểm tra tài nguyên:

```bash
# Kiểm tra resource usage
kubectl top nodes
kubectl top pods -n hadoop-ecosystem

# Kiểm tra storage
kubectl get pv
kubectl get pvc -n hadoop-ecosystem
```

## CÁC LỆNH HỮU ÍCH

```bash
# Xem tất cả resources
kubectl get all -n hadoop-ecosystem

# Xem events
kubectl get events -n hadoop-ecosystem --sort-by='.lastTimestamp'

# Shell vào container
kubectl exec -it deployment/hadoop-namenode -n hadoop-ecosystem -- bash

# Copy files
kubectl cp <local-file> hadoop-ecosystem/<pod>:<remote-path>

# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n hadoop-ecosystem
```

## SCRIPTS TỰ ĐỘNG

### Cài đặt nhanh toàn bộ hệ thống:

```bash
# Trên Master Node
./scripts/setup/install-master-node.sh

# Trên Worker Nodes (với join command)
./scripts/setup/install-worker-node.sh "<join-command>"

# Deploy ecosystem
make deploy

# Load sample data
make load-data
```

### Script kiểm tra hàng ngày:

```bash
# Tạo cron job để chạy health check hàng ngày
echo "0 8 * * * /path/to/hadoop-ecommerce-ecosystem/scripts/operations/health-check.sh" | crontab -
```

## HỖ TRỢ

Khi gặp vấn đề:

1. Kiểm tra logs: `kubectl logs <pod-name> -n hadoop-ecosystem`
2. Chạy health check: `./scripts/operations/health-check.sh`
3. Xem events: `kubectl get events -n hadoop-ecosystem`
4. Kiểm tra resource usage: `kubectl top nodes && kubectl top pods -n hadoop-ecosystem`

## KẾT LUẬN

Hệ thống Hadoop E-commerce Ecosystem đã được cài đặt thành công với:

✅ **1 Master Node**: 6GB RAM, 3 CPU cores  
✅ **2 Worker Nodes**: 4GB RAM, 2 CPU cores mỗi node  
✅ **Tổng tài nguyên**: 14GB RAM, 7 CPU cores  
✅ **Các thành phần**: Hadoop, Spark, Kafka, Hive, HBase, Airflow  
✅ **Monitoring**: Prometheus + Grafana  
✅ **Sample data**: Dữ liệu e-commerce mẫu  
✅ **Automation**: Scripts deploy và quản lý  

Hệ thống đã sẵn sàng cho việc phát triển và xử lý dữ liệu e-commerce quy mô lớn!