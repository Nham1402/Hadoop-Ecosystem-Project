# Hadoop E-commerce Ecosystem Makefile

.PHONY: help setup build deploy clean test monitor scale backup restore

# Default target
help:
	@echo "Available targets:"
	@echo "  setup     - Setup Kubernetes cluster and dependencies"
	@echo "  build     - Build all Docker images"
	@echo "  deploy    - Deploy all services to Kubernetes"
	@echo "  clean     - Clean up all resources"
	@echo "  test      - Run all tests"
	@echo "  monitor   - Deploy monitoring stack"
	@echo "  scale     - Scale worker nodes"
	@echo "  backup    - Backup all data"
	@echo "  restore   - Restore data from backup"

# Load environment variables
include .env
export

# Setup Kubernetes cluster
setup:
	@echo "Setting up Kubernetes cluster..."
	./scripts/setup/install-k8s.sh
	./scripts/setup/install-helm.sh
	./scripts/setup/setup-cluster.sh
	./scripts/setup/setup-storage.sh

# Build Docker images
build:
	@echo "Building Docker images..."
	docker build -t $(DOCKER_REGISTRY)/hadoop-base:$(HADOOP_VERSION) docker/hadoop-base/
	docker build -t $(DOCKER_REGISTRY)/spark:$(SPARK_VERSION) docker/spark/
	docker build -t $(DOCKER_REGISTRY)/hive:$(HIVE_VERSION) docker/hive/
	docker build -t $(DOCKER_REGISTRY)/hbase:$(HBASE_VERSION) docker/hbase/
	docker build -t $(DOCKER_REGISTRY)/kafka:$(KAFKA_VERSION) docker/kafka/
	docker build -t $(DOCKER_REGISTRY)/airflow:$(AIRFLOW_VERSION) docker/airflow/

# Push images to registry
push:
	@echo "Pushing images to registry..."
	docker push $(DOCKER_REGISTRY)/hadoop-base:$(HADOOP_VERSION)
	docker push $(DOCKER_REGISTRY)/spark:$(SPARK_VERSION)
	docker push $(DOCKER_REGISTRY)/hive:$(HIVE_VERSION)
	docker push $(DOCKER_REGISTRY)/hbase:$(HBASE_VERSION)
	docker push $(DOCKER_REGISTRY)/kafka:$(KAFKA_VERSION)
	docker push $(DOCKER_REGISTRY)/airflow:$(AIRFLOW_VERSION)

# Deploy all services
deploy:
	@echo "Deploying services..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	./scripts/deploy/deploy-all.sh

# Deploy individual components
deploy-hadoop:
	./scripts/deploy/deploy-hadoop.sh

deploy-spark:
	./scripts/deploy/deploy-spark.sh

deploy-kafka:
	./scripts/deploy/deploy-kafka.sh

deploy-hive:
	./scripts/deploy/deploy-hive.sh

deploy-hbase:
	./scripts/deploy/deploy-hbase.sh

deploy-airflow:
	./scripts/deploy/deploy-airflow.sh

deploy-monitoring:
	./scripts/deploy/deploy-monitoring.sh

# Monitoring
monitor:
	@echo "Deploying monitoring stack..."
	./scripts/deploy/deploy-monitoring.sh
	@echo "Access Grafana at: http://localhost:3000"
	@echo "Access Prometheus at: http://localhost:9090"

# Testing
test:
	@echo "Running tests..."
	./scripts/testing/test-hadoop.sh
	./scripts/testing/test-spark.sh
	./scripts/testing/test-kafka.sh
	./scripts/testing/integration-test.sh

# Data operations
load-data:
	@echo "Loading sample data..."
	./scripts/data/create-hdfs-dirs.sh
	./scripts/data/create-hive-tables.sh
	./scripts/data/create-hbase-tables.sh
	./scripts/data/create-kafka-topics.sh
	./scripts/data/sample-data-loader.sh

# Scaling
scale-workers:
	@echo "Scaling worker nodes..."
	./scripts/operations/scale-workers.sh $(REPLICAS)

# Backup and restore
backup:
	@echo "Backing up data..."
	./scripts/operations/backup-data.sh

restore:
	@echo "Restoring data..."
	./scripts/operations/restore-data.sh

# Health check
health:
	@echo "Checking cluster health..."
	./scripts/operations/health-check.sh

# Clean up
clean:
	@echo "Cleaning up resources..."
	./scripts/operations/cleanup.sh
	kubectl delete namespace $(NAMESPACE) --ignore-not-found=true

# Logs
logs-hadoop:
	kubectl logs -f -l app=hadoop-namenode -n $(NAMESPACE)

logs-spark:
	kubectl logs -f -l app=spark-master -n $(NAMESPACE)

logs-kafka:
	kubectl logs -f -l app=kafka -n $(NAMESPACE)

# Port forwarding for local access
forward-namenode:
	kubectl port-forward svc/hadoop-namenode 9870:9870 -n $(NAMESPACE)

forward-spark:
	kubectl port-forward svc/spark-master 8080:8080 -n $(NAMESPACE)

forward-kafka:
	kubectl port-forward svc/kafka 9092:9092 -n $(NAMESPACE)

forward-grafana:
	kubectl port-forward svc/grafana 3000:3000 -n $(NAMESPACE)

forward-airflow:
	kubectl port-forward svc/airflow-webserver 8080:8080 -n $(NAMESPACE)

# Development
dev-setup:
	@echo "Setting up development environment..."
	pip install -r requirements-dev.txt
	pre-commit install

# Linting
lint:
	flake8 spark/ airflow/ tests/
	yamllint kubernetes/ helm/