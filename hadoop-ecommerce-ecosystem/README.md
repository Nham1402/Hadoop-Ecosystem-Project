### Hadoop E-commerce Ecosystem trên VMware (1 Master, 2 Worker)

Tài liệu này hướng dẫn triển khai một hệ sinh thái Hadoop phục vụ bài toán thương mại điện tử trên 3 máy ảo VMware:
- Master: 8 GB RAM, 4 vCPU (hostname: hd-master)
- Worker 1: 4 GB RAM, 2 vCPU (hostname: hd-worker1)
- Worker 2: 4 GB RAM, 2 vCPU (hostname: hd-worker2)

Các thành phần chính:
- Hadoop HDFS + YARN (lưu trữ và tài nguyên tính toán)
- Spark (batch + streaming)
- Hive (warehouse SQL, metastore Postgres)
- Kafka (+ Zookeeper) cho ingest/stream
- HBase (NoSQL, user profile, catalog)
- Airflow (orchestration)
- Monitoring (Prometheus + Grafana) — tùy chọn

Lưu ý: Repo này kèm cấu trúc đầy đủ (Docker/K8s) để bạn mở rộng. Phần hướng dẫn dưới đây tập trung triển khai thẳng trên VM (bare metal). Docker Compose/Kubernetes để phát triển nội bộ/local hoặc mở rộng sau.

---

## 1) Chuẩn bị 3 máy ảo

Hệ điều hành khuyến nghị: Ubuntu Server 22.04 LTS.

Thiết lập hostname và IP tĩnh (ví dụ mạng 192.168.56.0/24):
- hd-master: 192.168.56.10
- hd-worker1: 192.168.56.11
- hd-worker2: 192.168.56.12

Thiết lập trên mỗi VM:
1. Đặt hostname (ví dụ trên master):
   ```bash
   sudo hostnamectl set-hostname hd-master
   ```
2. Cập nhật `/etc/hosts` (trên cả 3 máy):
   ```
   192.168.56.10 hd-master
   192.168.56.11 hd-worker1
   192.168.56.12 hd-worker2
   ```
3. Cập nhật hệ thống và công cụ cơ bản:
   ```bash
   sudo apt-get update && sudo apt-get -y upgrade
   sudo apt-get install -y curl wget vim git unzip net-tools htop openssh-server
   ```
4. Tắt swap (bắt buộc cho K8s, tốt cho Hadoop):
   ```bash
   sudo swapoff -a
   sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab
   ```
5. Tăng giới hạn file descriptor và vm.max_map_count (hỗ trợ ES/HBase):
   ```bash
   echo 'fs.file-max=1000000' | sudo tee -a /etc/sysctl.conf
   echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   echo '* soft nofile 1000000' | sudo tee -a /etc/security/limits.conf
   echo '* hard nofile 1000000' | sudo tee -a /etc/security/limits.conf
   ```
6. Thiết lập SSH không mật khẩu từ master tới các worker (chỉ thực hiện trên master):
   ```bash
   ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
   ssh-copy-id -o StrictHostKeyChecking=no hd-worker1
   ssh-copy-id -o StrictHostKeyChecking=no hd-worker2
   ```

---

## 2) Cài Java và tài khoản dịch vụ

Trên cả 3 máy:
```bash
sudo apt-get install -y openjdk-11-jdk
java -version
sudo adduser --disabled-password --gecos "" hadoop
echo 'hadoop ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/hadoop
sudo -u hadoop bash -lc 'ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa'
sudo -u hadoop bash -lc 'cat ~/.ssh/id_rsa.pub'
```
Copy public key của user `hadoop` trên master sang `~hadoop/.ssh/authorized_keys` trên worker1/worker2 (hoặc dùng `ssh-copy-id` với user hadoop).

Thiết lập biến môi trường (thêm vào `/etc/profile.d/java.sh` trên cả 3 máy):
```bash
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' | sudo tee /etc/profile.d/java.sh
echo 'export PATH=$JAVA_HOME/bin:$PATH' | sudo tee -a /etc/profile.d/java.sh
source /etc/profile.d/java.sh
```

---

## 3) Cài Hadoop 3.x (HDFS + YARN)

Phiên bản gợi ý: Hadoop 3.3.6. Thực hiện trên tất cả các máy:
```bash
HADOOP_VERSION=3.3.6
wget https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz
sudo tar -xzf hadoop-$HADOOP_VERSION.tar.gz -C /opt
sudo ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop
sudo chown -R hadoop:hadoop /opt/hadoop-$HADOOP_VERSION /opt/hadoop
```

Thêm biến môi trường cho hadoop (trên cả 3 máy, `/etc/profile.d/hadoop.sh`):
```bash
echo 'export HADOOP_HOME=/opt/hadoop' | sudo tee /etc/profile.d/hadoop.sh
echo 'export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop' | sudo tee -a /etc/profile.d/hadoop.sh
echo 'export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH' | sudo tee -a /etc/profile.d/hadoop.sh
source /etc/profile.d/hadoop.sh
```

Tạo thư mục dữ liệu (khác nhau giữa master/worker):
```bash
sudo mkdir -p /data/hdfs/namenode /data/hdfs/datanode
sudo chown -R hadoop:hadoop /data
```

Chỉnh cấu hình (trên tất cả các máy, với nội dung tương tự; thay `fs.defaultFS` trỏ tới master):
- `$HADOOP_CONF_DIR/core-site.xml`
```xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://hd-master:8020</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/data/hadoop-tmp</value>
  </property>
</configuration>
```

- `$HADOOP_CONF_DIR/hdfs-site.xml`
```xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>2</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:/data/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:/data/hdfs/datanode</value>
  </property>
</configuration>
```

- `$HADOOP_CONF_DIR/yarn-site.xml` (tất cả):
```xml
<configuration>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>hd-master</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
```

- `$HADOOP_CONF_DIR/mapred-site.xml` (tất cả):
```xml
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
```

Khai báo workers (chỉ trên master: `$HADOOP_CONF_DIR/workers`):
```
hd-worker1
hd-worker2
```

Khởi tạo HDFS (chỉ master, user hadoop):
```bash
sudo -u hadoop bash -lc 'hdfs namenode -format -force'
```

Khởi động dịch vụ (chỉ master):
```bash
start-dfs.sh
start-yarn.sh
```

Kiểm tra:
```bash
jps  # trên các máy nên thấy NameNode/DataNode/ResourceManager/NodeManager tương ứng
hdfs dfs -mkdir -p /data/raw
hdfs dfs -ls /
```

Web UIs:
- NameNode: http://hd-master:9870
- ResourceManager: http://hd-master:8088

---

## 4) Cài Spark 3.4.x

Trên cả 3 máy:
```bash
SPARK_VERSION=3.4.2
wget https://dlcdn.apache.org/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz
sudo tar -xzf spark-$SPARK_VERSION-bin-hadoop3.tgz -C /opt
sudo ln -s /opt/spark-$SPARK_VERSION-bin-hadoop3 /opt/spark
sudo chown -R hadoop:hadoop /opt/spark-
```

Biến môi trường (`/etc/profile.d/spark.sh`):
```bash
echo 'export SPARK_HOME=/opt/spark' | sudo tee /etc/profile.d/spark.sh
echo 'export PATH=$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH' | sudo tee -a /etc/profile.d/spark.sh
source /etc/profile.d/spark.sh
```

Chạy cluster-mode (đơn giản):
- Trên master: `start-master.sh`
- Trên mỗi worker: `start-slave.sh spark://hd-master:7077` (hoặc `start-worker.sh` tùy bản)

Web UI:
- Spark Master: http://hd-master:8080

---

## 5) Cài Hive 3.1.3 + Postgres (Metastore)

Trên master:
```bash
sudo apt-get install -y postgresql
sudo -u postgres psql -c "CREATE DATABASE metastore;"
sudo -u postgres psql -c "CREATE USER hive WITH PASSWORD 'hivepass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;"
```

Cài Hive:
```bash
HIVE_VERSION=3.1.3
wget https://dlcdn.apache.org/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz
sudo tar -xzf apache-hive-$HIVE_VERSION-bin.tar.gz -C /opt
sudo ln -s /opt/apache-hive-$HIVE_VERSION-bin /opt/hive
sudo chown -R hadoop:hadoop /opt/apache-hive-$HIVE_VERSION-bin /opt/hive
```

Thêm driver Postgres:
```bash
wget https://jdbc.postgresql.org/download/postgresql-42.7.4.jar -O /opt/hive/lib/postgresql.jar
```

`/opt/hive/conf/hive-site.xml` (rút gọn):
```xml
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:postgresql://localhost:5432/metastore</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>org.postgresql.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>hive</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>hivepass</value>
  </property>
</configuration>
```

Khởi tạo schema và chạy dịch vụ:
```bash
schematool -dbType postgres -initSchema
hive --service metastore &
hiveserver2 &
```

Kiểm tra Hive CLI: `beeline -u jdbc:hive2://hd-master:10000 -n hadoop`

---

## 6) Cài Zookeeper + Kafka 3.6

Trên master (demo 1 node; sản xuất nên tối thiểu 3 ZK/Kafka):
```bash
KAFKA_VERSION=3.6.1
SCALA_VERSION=2.13
wget https://dlcdn.apache.org/kafka/$KAFKA_VERSION/kafka_$SCALA_VERSION-$KAFKA_VERSION.tgz
sudo tar -xzf kafka_$SCALA_VERSION-$KAFKA_VERSION.tgz -C /opt
sudo ln -s /opt/kafka_$SCALA_VERSION-$KAFKA_VERSION /opt/kafka
sudo chown -R hadoop:hadoop /opt/kafka*
```

Chạy ZK và Kafka (đơn nút):
```bash
/opt/kafka/bin/zookeeper-server-start.sh -daemon /opt/kafka/config/zookeeper.properties
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties
```

Tạo topic ví dụ:
```bash
/opt/kafka/bin/kafka-topics.sh --create --topic user-events --bootstrap-server hd-master:9092 --replication-factor 1 --partitions 3
```

---

## 7) Cài HBase 2.5.x

Trên tất cả máy:
```bash
HBASE_VERSION=2.5.9
wget https://dlcdn.apache.org/hbase/$HBASE_VERSION/hbase-$HBASE_VERSION-bin.tar.gz
sudo tar -xzf hbase-$HBASE_VERSION-bin.tar.gz -C /opt
sudo ln -s /opt/hbase-$HBASE_VERSION /opt/hbase
sudo chown -R hadoop:hadoop /opt/hbase*
```

`/opt/hbase/conf/hbase-site.xml` (tối thiểu):
```xml
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://hd-master:8020/hbase</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>hd-master</value>
  </property>
</configuration>
```

Chạy dịch vụ:
- Master: `/opt/hbase/bin/start-hbase.sh`
- Tự động khởi động RegionServer trên worker nếu `conf/regionservers` liệt kê worker1/worker2.

---

## 8) Cài Airflow 2.x (tùy chọn, trên master)

```bash
sudo apt-get install -y python3-venv python3-pip
python3 -m venv ~/airflow-venv
source ~/airflow-venv/bin/activate
pip install "apache-airflow==2.8.4" --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.8.4/constraints-3.8.txt"
airflow db init
airflow users create --username admin --password admin --firstname A --lastname D --role Admin --email admin@example.com
export AIRFLOW_HOME=~/airflow
airflow webserver -p 8081 &
airflow scheduler &
```

Copy DAGs trong thư mục `airflow/dags/` của repo này vào `$AIRFLOW_HOME/dags/`.

---

## 9) Luồng dữ liệu mẫu (E-commerce)

- Ingest sự kiện thời gian thực: ứng dụng/producer đẩy `user-events` (view, add_to_cart, purchase) vào Kafka topic `user-events`.
- Streaming: Spark Structured Streaming đọc `user-events` từ Kafka, chuẩn hóa, ghi ra HDFS (`/data/events/date=.../`) và bảng Hive external phân vùng theo ngày.
- Batch hằng ngày: job `daily_sales_report.py` đọc `orders.csv`/`transactions.csv` trong HDFS, join với `products`, tính doanh thu, ghi kết quả vào Hive table `mart.daily_sales` và HDFS `/reports/daily_sales/`.
- HBase: lưu `user_profiles` phục vụ gợi ý/tra cứu nhanh theo userId.
- Airflow: DAG `daily_etl_pipeline.py` điều phối nạp dữ liệu, chạy Spark job, và `MSCK REPAIR TABLE` cho Hive.

Lệnh kiểm thử nhanh:
```bash
# 1) Đẩy dữ liệu mẫu lên HDFS
hdfs dfs -mkdir -p /data/raw
hdfs dfs -put data/sample-data/*.csv /data/raw/

# 2) Chạy Spark job báo cáo doanh thu
/opt/spark/bin/spark-submit \
  --master spark://hd-master:7077 \
  spark/jobs/batch-processing/daily_sales_report.py \
  --input /data/raw/orders.csv --products /data/raw/products.csv \
  --output /reports/daily_sales

# 3) Kiểm tra kết quả
hdfs dfs -ls /reports/daily_sales
```

---

## 10) Phát triển và mở rộng

- Thư mục `docker/` và `docker-compose.yml`: chạy nhanh môi trường phát triển một máy.
- Thư mục `kubernetes/` và `helm/`: dùng khi bạn muốn chuyển lên K8s.
- Thư mục `monitoring/`: mẫu cấu hình Prometheus/Grafana.

Best practices tóm tắt:
- Dùng 3-nút trở lên cho Zookeeper/Kafka khi chạy thực tế.
- Đặt replication factor HDFS >= 2, Kafka >= 2.
- Tách disk cho NameNode/DataNode/commit log Kafka.
- Sao lưu định kỳ HDFS/Hive Metastore.

---

## 11) Cấu trúc repo

Xem chi tiết trong cây thư mục ở mô tả dự án. Những file cốt lõi đã được cung cấp để chạy nhanh: dữ liệu mẫu, job Spark, DAG Airflow, producer Kafka, và hướng dẫn cài đặt.

