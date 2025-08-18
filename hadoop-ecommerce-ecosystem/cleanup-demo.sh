#!/bin/bash

echo "Dọn dẹp Hadoop E-commerce Demo..."

# Dừng và xóa containers, volumes
docker-compose -f docker-compose-demo.yml down -v

# Xóa images (tùy chọn)
read -p "Bạn có muốn xóa Docker images không? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose -f docker-compose-demo.yml down --rmi all -v
fi

echo "Demo đã được dọn dẹp."
