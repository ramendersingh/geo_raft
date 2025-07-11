#!/bin/bash

# Start Prometheus monitoring stack
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_DIR"

echo "Starting Prometheus monitoring stack..."

# Create external network if it doesn't exist
docker network create fabric 2>/dev/null || true

# Start Prometheus stack
docker compose -f monitoring/prometheus/docker-compose.prometheus.yml up -d

echo "✅ Prometheus monitoring stack started!"
echo "🔍 Prometheus: http://localhost:9090"
echo "📊 Grafana: http://localhost:3001 (admin/admin123)"
echo "📈 Node Exporter: http://localhost:9100"
