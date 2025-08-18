#!/bin/bash

echo "Loading sample data into PostgreSQL..."

# Chờ PostgreSQL sẵn sàng
sleep 10

# Load data
docker exec -i $(docker-compose -f docker-compose-demo.yml ps -q postgres) psql -U hadoop -d ecommerce < demo-data/sample-data.sql

echo "Sample data loaded successfully!"
echo ""
echo "Connect to database:"
echo "psql -h localhost -U hadoop -d ecommerce"
echo "Password: password"
