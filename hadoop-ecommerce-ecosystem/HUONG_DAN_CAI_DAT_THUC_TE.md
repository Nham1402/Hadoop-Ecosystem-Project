# HƯỚNG DẪN CÀI ĐẶT THỰC TẾ CHO HỆ THỐNG HADOOP E-COMMERCE

## 🚨 QUAN TRỌNG: Môi trường cài đặt

Để cài đặt thành công hệ thống Hadoop E-commerce Ecosystem, bạn cần:

### **Yêu cầu hệ thống:**
- **3 máy Ubuntu 20.04/22.04 LTS** (vật lý hoặc VM)
- **1 Master Node**: 6GB RAM, 3 CPU cores, 100GB disk
- **2 Worker Nodes**: 4GB RAM, 2 CPU cores, 200GB disk mỗi máy
- **Kết nối mạng** giữa các máy
- **Quyền sudo** trên tất cả các máy

---

## 📋 BƯỚC 1: CHUẨN BỊ TẤT CẢ CÁC NODES

### Trên tất cả 3 máy, chạy:

```bash
# 1. Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# 2. Clone repository
git clone https://github.com/your-repo/hadoop-ecommerce-ecosystem.git
cd hadoop-ecommerce-ecosystem

# 3. Cài đặt các ứng dụng cần thiết
chmod +x scripts/setup/install-prerequisites.sh
./scripts/setup/install-prerequisites.sh
```

### Thiết lập hostname và hosts file:

```bash
# Trên Master Node
sudo hostnamectl set-hostname master-node

# Trên Worker Node 1
sudo hostnamectl set-hostname worker-node-1

# Trên Worker Node 2
sudo hostnamectl set-hostname worker-node-2

# Trên tất cả nodes, thêm vào /etc/hosts:
sudo nano /etc/hosts
# Thêm:
192.168.1.10  master-node
192.168.1.11  worker-node-1
192.168.1.12  worker-node-2
```

---

## 🎯 BƯỚC 2: CÀI ĐẶT MASTER NODE

### Trên máy Master Node (6GB RAM, 3 CPU):

```bash
# 1. Chạy script cài đặt master
chmod +x scripts/setup/install-master-node.sh
./scripts/setup/install-master-node.sh

# 2. Lấy lệnh join cho worker nodes
sudo kubeadm token create --print-join-command

# Lưu lệnh này để sử dụng trên worker nodes
```

### Kiểm tra Master Node:

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

---

## 👥 BƯỚC 3: CÀI ĐẶT WORKER NODES

### Trên mỗi Worker Node (4GB RAM, 2 CPU):

```bash
# 1. Clone repository (nếu chưa có)
git clone https://github.com/your-repo/hadoop-ecommerce-ecosystem.git
cd hadoop-ecommerce-ecosystem

# 2. Chạy script cài đặt worker với lệnh join từ master
chmod +x scripts/setup/install-worker-node.sh
./scripts/setup/install-worker-node.sh "sudo kubeadm join 192.168.1.10:6443 --token <token> --discovery-token-ca-cert-hash <hash>"
```

### Từ Master Node, cấu hình worker nodes:

```bash
# Gắn nhãn cho worker nodes
kubectl label node worker-node-1 node-role=worker
kubectl label node worker-node-2 node-role=worker

# Kiểm tra tất cả nodes
kubectl get nodes -o wide
```

---

## 🚀 BƯỚC 4: TRIỂN KHAI HADOOP ECOSYSTEM

### Từ Master Node:

```bash
# 1. Tạo namespace và cấu hình
kubectl create namespace hadoop-ecosystem

# 2. Build Docker images (nếu cần)
make build

# 3. Triển khai toàn bộ hệ thống
make deploy

# Hoặc triển khai từng bước:
./scripts/deploy/deploy-all.sh
```

### Kiểm tra triển khai:

```bash
# Xem tất cả pods
kubectl get pods -n hadoop-ecosystem

# Xem services
kubectl get services -n hadoop-ecosystem

# Chạy health check
./scripts/operations/health-check.sh
```

---

## 🌐 BƯỚC 5: TRUY CẬP HỆ THỐNG

### Cấu hình truy cập từ bên ngoài:

```bash
# Trên Master Node, cấu hình port forwarding:

# Hadoop NameNode
kubectl port-forward -n hadoop-ecosystem svc/hadoop-namenode 9870:9870 &

# Spark Master
kubectl port-forward -n hadoop-ecosystem svc/spark-master 8080:8080 &

# YARN ResourceManager
kubectl port-forward -n hadoop-ecosystem svc/yarn-resourcemanager 8088:8088 &

# Grafana Monitoring
kubectl port-forward -n hadoop-ecosystem svc/grafana 3000:3000 &
```

### Hoặc sử dụng NodePort (truy cập qua IP của nodes):

- **Hadoop NameNode**: `http://<master-ip>:30870`
- **YARN ResourceManager**: `http://<master-ip>:30088`
- **Spark Master**: `http://<master-ip>:30080`
- **Grafana**: `http://<master-ip>:30300`

---

## 📊 BƯỚC 6: LOAD DỮ LIỆU VÀ CHẠY JOBS

### Load dữ liệu mẫu:

```bash
# Từ Master Node
make load-data

# Hoặc thủ công:
./scripts/data/sample-data-loader.sh
```

### Chạy Spark job mẫu:

```bash
# Submit daily sales report job
kubectl exec -n hadoop-ecosystem deployment/spark-master -- \
  spark-submit \
  --master spark://spark-master:7077 \
  --deploy-mode client \
  /opt/spark/jobs/batch-processing/daily_sales_report.py
```

### Kích hoạt Airflow DAG:

1. Truy cập Airflow UI: `http://<master-ip>:8080`
2. Login với `admin/admin`
3. Enable DAG `daily_etl_pipeline`
4. Trigger manual run

---

## 🔧 SCRIPTS TỰ ĐỘNG ĐÃ TẠO

### Scripts cài đặt:

```bash
scripts/setup/install-prerequisites.sh     # Cài Docker, K8s, Helm, Java
scripts/setup/install-master-node.sh       # Cài đặt Master Node
scripts/setup/install-worker-node.sh       # Cài đặt Worker Node
scripts/setup/setup-cluster.sh             # Cấu hình cluster
```

### Scripts triển khai:

```bash
scripts/deploy/deploy-all.sh               # Deploy toàn bộ hệ thống
scripts/deploy/deploy-hadoop.sh            # Deploy chỉ Hadoop
scripts/deploy/deploy-spark.sh             # Deploy chỉ Spark
scripts/deploy/deploy-monitoring.sh        # Deploy monitoring
```

### Scripts quản lý:

```bash
scripts/operations/health-check.sh         # Kiểm tra sức khỏe hệ thống
scripts/operations/scale-workers.sh        # Scale workers
scripts/operations/backup-data.sh          # Backup dữ liệu
scripts/operations/cleanup.sh              # Dọn dẹp
```

---

## 📈 GIÁM SÁT VÀ QUẢN LÝ

### Monitoring với Grafana:

```bash
# Truy cập Grafana
kubectl port-forward -n hadoop-ecosystem svc/grafana 3000:3000

# Mở browser: http://localhost:3000
# Login: admin/admin
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

### Health check định kỳ:

```bash
# Chạy health check
./scripts/operations/health-check.sh

# Tạo cron job để chạy hàng ngày
echo "0 8 * * * /path/to/scripts/operations/health-check.sh" | crontab -
```

---

## 🛠️ TROUBLESHOOTING

### Vấn đề thường gặp:

#### 1. Pods không khởi động:
```bash
kubectl describe pod <pod-name> -n hadoop-ecosystem
kubectl logs <pod-name> -n hadoop-ecosystem
```

#### 2. Nodes không join được:
```bash
# Trên worker node:
sudo systemctl status kubelet
sudo journalctl -xeu kubelet

# Reset và thử lại:
sudo kubeadm reset
```

#### 3. Docker daemon không chạy:
```bash
sudo systemctl status docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### 4. Thiếu tài nguyên:
```bash
# Kiểm tra resource usage
kubectl top nodes
kubectl top pods -n hadoop-ecosystem

# Scale down nếu cần
kubectl scale deployment <deployment-name> --replicas=1 -n hadoop-ecosystem
```

---

## 📋 CHECKLIST CÀI ĐẶT

### ✅ Chuẩn bị:
- [ ] 3 máy Ubuntu với cấu hình đủ
- [ ] Kết nối mạng giữa các máy
- [ ] Quyền sudo trên tất cả máy
- [ ] Repository đã được clone

### ✅ Master Node:
- [ ] Docker đã cài đặt và chạy
- [ ] Kubernetes tools đã cài đặt
- [ ] Cluster đã được khởi tạo
- [ ] kubectl hoạt động bình thường
- [ ] CNI (Flannel) đã được cài đặt

### ✅ Worker Nodes:
- [ ] Docker và K8s tools đã cài đặt
- [ ] Đã join cluster thành công
- [ ] Nodes có label phù hợp
- [ ] kubelet đang chạy

### ✅ Hadoop Ecosystem:
- [ ] Namespace hadoop-ecosystem đã tạo
- [ ] ConfigMaps và Secrets đã apply
- [ ] Storage đã được cấu hình
- [ ] Tất cả pods đang chạy
- [ ] Services có endpoints

### ✅ Kiểm tra cuối:
- [ ] Web UIs có thể truy cập
- [ ] Sample data đã được load
- [ ] Spark jobs chạy thành công
- [ ] Monitoring hoạt động
- [ ] Health check pass

---

## 🎯 KẾT QUẢ MONG ĐỢI

Sau khi hoàn thành, bạn sẽ có:

✅ **Kubernetes cluster** với 1 master + 2 workers  
✅ **Hadoop HDFS** với NameNode và 2 DataNodes  
✅ **Apache Spark** với Master và 2 Workers  
✅ **Apache Kafka** cho real-time streaming  
✅ **Apache Hive** cho data warehousing  
✅ **Apache HBase** cho NoSQL storage  
✅ **Apache Airflow** cho workflow orchestration  
✅ **Monitoring stack** với Prometheus + Grafana  
✅ **Sample e-commerce data** và analytics jobs  

**Tổng tài nguyên**: 14GB RAM, 7 CPU cores như yêu cầu ban đầu!

---

## 📞 HỖ TRỢ

Nếu gặp vấn đề:

1. **Kiểm tra logs**: `kubectl logs <pod-name> -n hadoop-ecosystem`
2. **Chạy health check**: `./scripts/operations/health-check.sh`
3. **Xem events**: `kubectl get events -n hadoop-ecosystem`
4. **Kiểm tra tài nguyên**: `kubectl top nodes && kubectl top pods -n hadoop-ecosystem`

**Lưu ý**: Hệ thống này được thiết kế để chạy trên môi trường thực với Docker và Kubernetes đầy đủ. Trong môi trường container/sandbox có thể gặp hạn chế về systemd và kernel modules.