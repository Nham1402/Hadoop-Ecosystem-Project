#!/usr/bin/env bash
set -euo pipefail
echo "Removing stack 'hadoop'"
docker stack rm hadoop || true
echo "Waiting for services to drain..."
sleep 5
docker service ls || true

