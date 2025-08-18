#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP=${BOOTSTRAP:-"localhost:9092"}

create_topic() {
  local topic=$1
  local partitions=${2:-3}
  local rf=${3:-1}
  kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --create --if-not-exists \
    --topic "$topic" --partitions "$partitions" --replication-factor "$rf" || true
}

create_topic user-events 3 1
create_topic transactions 3 1
create_topic inventory 1 1

echo "Topics ensured on $BOOTSTRAP"

