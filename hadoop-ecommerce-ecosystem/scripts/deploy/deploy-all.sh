#!/bin/bash

set -e

echo "Deploying Hadoop E-commerce Ecosystem..."

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

# Wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local namespace=${2:-$NAMESPACE}
    local timeout=${3:-300}
    
    log_info "Waiting for deployment $deployment to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace
}

# Wait for statefulset to be ready
wait_for_statefulset() {
    local statefulset=$1
    local namespace=${2:-$NAMESPACE}
    local timeout=${3:-300}
    
    log_info "Waiting for statefulset $statefulset to be ready..."
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=2 --timeout=${timeout}s statefulset/$statefulset -n $namespace
}

# Deploy Zookeeper
deploy_zookeeper() {
    log_info "Deploying Zookeeper..."
    kubectl apply -f kubernetes/deployments/zookeeper/
    kubectl apply -f kubernetes/services/zookeeper-service.yaml
    wait_for_deployment zookeeper
}

# Deploy Hadoop
deploy_hadoop() {
    log_info "Deploying Hadoop cluster..."
    
    # Deploy services first
    kubectl apply -f kubernetes/services/hadoop-services.yaml
    
    # Deploy master components
    kubectl apply -f kubernetes/deployments/hadoop/hadoop-master.yaml
    wait_for_deployment hadoop-namenode
    wait_for_deployment yarn-resourcemanager
    
    # Deploy worker components
    kubectl apply -f kubernetes/deployments/hadoop/hadoop-workers.yaml
    wait_for_statefulset hadoop-datanode
    wait_for_statefulset yarn-nodemanager
    
    log_info "Hadoop cluster deployed successfully!"
}

# Deploy Spark
deploy_spark() {
    log_info "Deploying Spark cluster..."
    
    # Deploy services first
    kubectl apply -f kubernetes/services/spark-services.yaml
    
    # Deploy master
    kubectl apply -f kubernetes/deployments/spark/spark-master.yaml
    wait_for_deployment spark-master
    
    # Deploy workers
    kubectl apply -f kubernetes/deployments/spark/spark-workers.yaml
    wait_for_statefulset spark-worker
    
    log_info "Spark cluster deployed successfully!"
}

# Deploy Kafka
deploy_kafka() {
    log_info "Deploying Kafka..."
    kubectl apply -f kubernetes/deployments/kafka/
    kubectl apply -f kubernetes/services/kafka-service.yaml
    wait_for_deployment kafka
}

# Deploy Hive
deploy_hive() {
    log_info "Deploying Hive..."
    
    # Deploy PostgreSQL first
    kubectl apply -f kubernetes/deployments/hive/postgres.yaml
    wait_for_deployment postgres
    
    # Deploy Hive services
    kubectl apply -f kubernetes/deployments/hive/
    kubectl apply -f kubernetes/services/hive-services.yaml
    wait_for_deployment hive-metastore
    wait_for_deployment hiveserver2
}

# Deploy HBase
deploy_hbase() {
    log_info "Deploying HBase..."
    kubectl apply -f kubernetes/deployments/hbase/
    kubectl apply -f kubernetes/services/hbase-services.yaml
    wait_for_deployment hbase-master
    wait_for_statefulset hbase-regionserver
}

# Deploy Airflow
deploy_airflow() {
    log_info "Deploying Airflow..."
    kubectl apply -f kubernetes/deployments/airflow/
    kubectl apply -f kubernetes/services/airflow-services.yaml
    wait_for_deployment airflow-webserver
    wait_for_deployment airflow-scheduler
}

# Deploy monitoring stack
deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    kubectl apply -f kubernetes/deployments/monitoring/
    kubectl apply -f kubernetes/services/monitoring-services.yaml
    wait_for_deployment prometheus
    wait_for_deployment grafana
}

# Create initial HDFS directories
setup_hdfs() {
    log_info "Setting up HDFS directories..."
    sleep 30  # Wait for namenode to be fully ready
    
    # Run setup script in namenode pod
    kubectl exec -n $NAMESPACE deployment/hadoop-namenode -- /bin/bash -c "
        hdfs dfs -mkdir -p /user
        hdfs dfs -mkdir -p /tmp
        hdfs dfs -mkdir -p /spark-logs
        hdfs dfs -mkdir -p /spark-warehouse
        hdfs dfs -mkdir -p /hive/warehouse
        hdfs dfs -chmod 777 /tmp
        hdfs dfs -chmod 777 /spark-logs
        hdfs dfs -chmod 777 /spark-warehouse
        hdfs dfs -chmod 777 /hive/warehouse
    "
    
    log_info "HDFS directories created successfully!"
}

# Display access information
display_access_info() {
    echo ""
    echo "=== Deployment Complete ==="
    echo ""
    echo "Web UIs (use kubectl port-forward or NodePort):"
    echo "- Hadoop NameNode: http://localhost:9870 (NodePort: 30870)"
    echo "- YARN ResourceManager: http://localhost:8088 (NodePort: 30088)"
    echo "- Spark Master: http://localhost:8080 (NodePort: 30080)"
    echo "- Airflow: http://localhost:8080"
    echo "- Grafana: http://localhost:3000"
    echo ""
    echo "Port Forward Commands:"
    echo "kubectl port-forward -n $NAMESPACE svc/hadoop-namenode 9870:9870"
    echo "kubectl port-forward -n $NAMESPACE svc/yarn-resourcemanager 8088:8088"
    echo "kubectl port-forward -n $NAMESPACE svc/spark-master 8080:8080"
    echo "kubectl port-forward -n $NAMESPACE svc/airflow-webserver 8080:8080"
    echo "kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
    echo ""
}

# Check deployment status
check_deployment_status() {
    echo "=== Deployment Status ==="
    kubectl get pods -n $NAMESPACE
    echo ""
    kubectl get services -n $NAMESPACE
    echo ""
}

# Main deployment function
main() {
    log_info "Starting deployment of Hadoop E-commerce Ecosystem..."
    
    # Deploy in order of dependencies
    deploy_zookeeper
    deploy_hadoop
    deploy_spark
    deploy_kafka
    deploy_hive
    deploy_hbase
    deploy_airflow
    deploy_monitoring
    
    # Setup HDFS
    setup_hdfs
    
    # Check status
    check_deployment_status
    
    # Display access information
    display_access_info
    
    log_info "Deployment completed successfully!"
}

# Run main function
main "$@"