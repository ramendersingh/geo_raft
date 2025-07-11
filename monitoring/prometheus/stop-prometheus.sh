#!/bin/bash

# Stop Prometheus monitoring stack
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_DIR"

echo "Stopping Prometheus monitoring stack..."

# Stop Prometheus stack
docker compose -f monitoring/prometheus/docker-compose.prometheus.yml down

echo "✅ Prometheus monitoring stack stopped!"
