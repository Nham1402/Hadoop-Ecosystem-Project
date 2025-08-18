# Hadoop E-commerce Ecosystem

A complete big data ecosystem for e-commerce analytics built with Hadoop, Spark, Kafka, Hive, HBase, and other tools, deployed on Kubernetes.

## Architecture

- **Master Node**: 6GB RAM, 3 CPU cores
- **Worker Nodes**: 2 nodes, each with 4GB RAM, 2 CPU cores
- **Platform**: Ubuntu with Kubernetes orchestration

## Components

- **Hadoop HDFS**: Distributed storage
- **Apache Spark**: Batch and stream processing
- **Apache Kafka**: Real-time data streaming
- **Apache Hive**: Data warehousing
- **Apache HBase**: NoSQL database
- **Apache Cassandra**: Time-series data
- **Apache Airflow**: Workflow orchestration
- **Monitoring**: Prometheus, Grafana, ELK Stack

## Quick Start

```bash
# Setup Kubernetes cluster
./scripts/setup/setup-cluster.sh

# Deploy all components
./scripts/deploy/deploy-all.sh

# Load sample data
./scripts/data/sample-data-loader.sh
```

## Directory Structure

- `docker/`: Docker images and configurations
- `kubernetes/`: K8s manifests and deployments
- `helm/`: Helm charts for deployment
- `scripts/`: Automation and utility scripts
- `airflow/`: Workflow definitions and plugins
- `spark/`: Spark jobs and applications
- `kafka/`: Streaming configurations
- `monitoring/`: Observability stack
- `data/`: Sample datasets and schemas
- `tests/`: Test suites and fixtures

## Resource Requirements

- **Total**: 14GB RAM, 7 CPU cores
- **Storage**: 500GB+ for data storage
- **Network**: High-bandwidth for inter-node communication

## Documentation

See the `docs/` directory for detailed documentation on:
- System architecture
- Deployment guide
- Operations manual
- Development guide

## License

MIT License