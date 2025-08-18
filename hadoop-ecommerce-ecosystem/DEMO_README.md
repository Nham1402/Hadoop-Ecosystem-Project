# Hadoop E-commerce Ecosystem - Demo

## Giới thiệu

Đây là phiên bản demo đơn giản của Hadoop E-commerce Ecosystem sử dụng Docker Compose, phù hợp để chạy trên máy local hoặc môi trường có hạn chế.

## Yêu cầu

- Docker và Docker Compose
- 4GB RAM trở lên
- 10GB disk space trống

## Cấu trúc Demo

```
├── docker-compose-demo.yml    # Docker Compose configuration
├── start-demo.sh             # Script khởi động
├── stop-demo.sh              # Script dừng
├── cleanup-demo.sh           # Script dọn dẹp
└── demo-data/
    ├── sample-data.sql       # Sample database
    └── load-sample-data.sh   # Script load data
```

## Các Services

- **Zookeeper**: Coordination service
- **Kafka**: Message streaming
- **PostgreSQL**: Relational database
- **Hadoop NameNode**: HDFS metadata
- **Hadoop DataNode**: HDFS storage
- **Spark Master**: Spark cluster coordinator
- **Spark Worker**: Spark processing node
- **Grafana**: Monitoring dashboard
- **Prometheus**: Metrics collection

## Cách sử dụng

### 1. Khởi động demo
```bash
./start-demo.sh
```

### 2. Load sample data
```bash
./demo-data/load-sample-data.sh
```

### 3. Truy cập Web UIs
- Hadoop NameNode: http://localhost:9870
- Spark Master: http://localhost:8080
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

### 4. Kết nối database
```bash
psql -h localhost -U hadoop -d ecommerce
# Password: password
```

### 5. Dừng demo
```bash
./stop-demo.sh
```

### 6. Dọn dẹp (xóa tất cả data)
```bash
./cleanup-demo.sh
```

## Giám sát

- **Logs**: `docker-compose -f docker-compose-demo.yml logs [service]`
- **Status**: `docker-compose -f docker-compose-demo.yml ps`
- **Stats**: `docker stats`

## Hạn chế của Demo

- Chỉ 1 DataNode và 1 Spark Worker
- Không có High Availability
- Không có security
- Tài nguyên hạn chế
- Không có persistent storage optimization

## Chuyển sang Production

Để triển khai production, sử dụng:
- Kubernetes manifests trong thư mục `kubernetes/`
- Helm charts trong thư mục `helm/`
- Scripts cài đặt trong `scripts/setup/`

Xem `HUONG_DAN_CAI_DAT_THUC_TE.md` để biết chi tiết.
