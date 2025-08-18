# Hadoop E-commerce Ecosystem Installation Guide

This guide provides step-by-step instructions for deploying the complete Hadoop e-commerce ecosystem on Ubuntu with Kubernetes.

## Architecture Overview

- **Master Node**: 6GB RAM, 3 CPU cores
- **Worker Nodes**: 2 nodes, each with 4GB RAM, 2 CPU cores
- **Total Resources**: 14GB RAM, 7 CPU cores

## Components

- Hadoop HDFS (Distributed Storage)
- Apache Spark (Batch & Stream Processing)
- Apache Kafka (Real-time Streaming)
- Apache Hive (Data Warehousing)
- Apache HBase (NoSQL Database)
- Apache Airflow (Workflow Orchestration)
- PostgreSQL (Metadata Storage)
- Prometheus & Grafana (Monitoring)

## Prerequisites

### System Requirements

1. **Hardware**:
   - 3 Ubuntu 20.04/22.04 servers
   - 1 Master: 6GB RAM, 3 CPU cores, 100GB disk
   - 2 Workers: 4GB RAM, 2 CPU cores, 200GB disk each

2. **Network**:
   - All nodes in same network with SSH access
   - Internet connectivity for package downloads

3. **Software**:
   - Ubuntu 20.04 or 22.04 LTS
   - Sudo access on all nodes

## Installation Steps

### Step 1: Prepare All Nodes

Run on all nodes (master and workers):

```bash
# Clone the repository
git clone <repository-url>
cd hadoop-ecommerce-ecosystem

# Install Kubernetes
chmod +x scripts/setup/install-k8s.sh
./scripts/setup/install-k8s.sh
```

This script will:
- Install Docker
- Install Kubernetes tools (kubeadm, kubelet, kubectl)
- Configure system settings
- Initialize cluster (master only)
- Install Helm and additional tools

### Step 2: Join Worker Nodes

On master node, get the join command:
```bash
sudo kubeadm token create --print-join-command
```

Run the join command on each worker node:
```bash
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### Step 3: Verify Cluster

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Step 4: Setup Cluster Configuration

```bash
# Setup cluster with proper node labels and storage
./scripts/setup/setup-cluster.sh
```

### Step 5: Build Docker Images

```bash
# Build all Docker images
make build

# Or build individually
docker build -t hadoop-base:3.3.4 docker/hadoop-base/
docker build -t spark:3.4.1 docker/spark/
```

### Step 6: Deploy the Ecosystem

Option A - Using Make:
```bash
make deploy
```

Option B - Using Scripts:
```bash
./scripts/deploy/deploy-all.sh
```

Option C - Using Helm:
```bash
helm install hadoop-ecosystem helm/hadoop-ecosystem/ \
  --namespace hadoop-ecosystem \
  --create-namespace \
  --values helm/hadoop-ecosystem/values.yaml
```

### Step 7: Verify Deployment

```bash
# Check deployment status
./scripts/operations/health-check.sh

# Check pods
kubectl get pods -n hadoop-ecosystem

# Check services
kubectl get services -n hadoop-ecosystem
```

## Accessing Web UIs

### Port Forwarding (Local Access)

```bash
# Hadoop NameNode
kubectl port-forward -n hadoop-ecosystem svc/hadoop-namenode 9870:9870
# Access: http://localhost:9870

# YARN ResourceManager
kubectl port-forward -n hadoop-ecosystem svc/yarn-resourcemanager 8088:8088
# Access: http://localhost:8088

# Spark Master
kubectl port-forward -n hadoop-ecosystem svc/spark-master 8080:8080
# Access: http://localhost:8080

# Airflow
kubectl port-forward -n hadoop-ecosystem svc/airflow-webserver 8080:8080
# Access: http://localhost:8080

# Grafana
kubectl port-forward -n hadoop-ecosystem svc/grafana 3000:3000
# Access: http://localhost:3000 (admin/admin)
```

### NodePort Access (External Access)

UIs are also available via NodePort:
- Hadoop NameNode: http://\<node-ip\>:30870
- YARN ResourceManager: http://\<node-ip\>:30088
- Spark Master: http://\<node-ip\>:30080

## Loading Sample Data

```bash
# Load sample e-commerce data
make load-data

# Or run manually
./scripts/data/sample-data-loader.sh
```

## Running Sample Jobs

### Daily Sales Report

```bash
# Submit Spark job for daily sales analysis
kubectl exec -n hadoop-ecosystem deployment/spark-master -- \
  spark-submit \
  --master spark://spark-master:7077 \
  --deploy-mode client \
  /opt/spark/jobs/batch-processing/daily_sales_report.py
```

### Airflow DAGs

Access Airflow UI and enable the `daily_etl_pipeline` DAG for automated data processing.

## Monitoring

### Prometheus Metrics

- Hadoop metrics: http://\<node-ip\>:30090
- Grafana dashboards: http://\<node-ip\>:30300

### Log Analysis

```bash
# View logs for specific components
kubectl logs -f -l app=hadoop,component=namenode -n hadoop-ecosystem
kubectl logs -f -l app=spark,component=master -n hadoop-ecosystem
```

## Scaling

### Scale Worker Nodes

```bash
# Add more worker nodes to Kubernetes cluster
# Then scale Hadoop and Spark workers
kubectl scale statefulset hadoop-datanode --replicas=3 -n hadoop-ecosystem
kubectl scale statefulset spark-worker --replicas=3 -n hadoop-ecosystem
```

### Resource Adjustment

Edit the resource limits in Kubernetes manifests or Helm values:

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2"
  limits:
    memory: "6Gi"
    cpu: "3"
```

## Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**:
   ```bash
   kubectl describe pod <pod-name> -n hadoop-ecosystem
   # Check for resource constraints or node selector issues
   ```

2. **NameNode fails to start**:
   ```bash
   # Check if namenode data directory is properly mounted
   kubectl exec -n hadoop-ecosystem deployment/hadoop-namenode -- ls -la /hadoop/dfs/name
   ```

3. **Spark jobs fail**:
   ```bash
   # Check Spark master logs
   kubectl logs -f deployment/spark-master -n hadoop-ecosystem
   ```

### Health Checks

```bash
# Comprehensive health check
./scripts/operations/health-check.sh

# Check specific components
kubectl get pods -n hadoop-ecosystem -l app=hadoop
kubectl get pods -n hadoop-ecosystem -l app=spark
```

### Backup and Recovery

```bash
# Backup HDFS data
./scripts/operations/backup-data.sh

# Restore from backup
./scripts/operations/restore-data.sh
```

## Performance Tuning

### Hadoop Configuration

Edit `kubernetes/configmaps/hadoop-config.yaml`:
- Adjust heap sizes based on available memory
- Tune block size and replication factor
- Configure compression codecs

### Spark Configuration

Edit `kubernetes/configmaps/spark-config.yaml`:
- Adjust executor memory and cores
- Enable dynamic allocation
- Configure shuffle parameters

### Kubernetes Resource Limits

Update resource requests and limits in deployment manifests based on actual usage patterns.

## Production Considerations

1. **High Availability**:
   - Deploy multiple NameNodes with HA configuration
   - Use external PostgreSQL with replication
   - Configure Kafka and Zookeeper clusters

2. **Security**:
   - Enable Kerberos authentication
   - Configure SSL/TLS for all components
   - Use Kubernetes RBAC and network policies

3. **Storage**:
   - Use persistent volumes with appropriate storage classes
   - Configure backup and disaster recovery
   - Monitor disk usage and implement retention policies

4. **Monitoring**:
   - Set up alerting rules in Prometheus
   - Configure log aggregation with ELK stack
   - Implement custom metrics for business KPIs

## Support

For issues and questions:
- Check logs: `kubectl logs <pod-name> -n hadoop-ecosystem`
- Run health checks: `./scripts/operations/health-check.sh`
- Review Kubernetes events: `kubectl get events -n hadoop-ecosystem`

## Next Steps

1. Customize the data schemas for your specific e-commerce use case
2. Develop additional Spark jobs for advanced analytics
3. Configure real-time streaming with Kafka producers
4. Set up automated backup and monitoring alerts
5. Implement CI/CD pipelines for job deployment