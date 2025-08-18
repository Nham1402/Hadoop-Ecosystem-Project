#!/bin/bash

echo "Dừng Hadoop E-commerce Demo..."

# Dừng tất cả services
docker-compose -f docker-compose-demo.yml down

echo "Demo đã được dừng."
