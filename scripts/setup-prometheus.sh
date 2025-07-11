#!/bin/bash

# Prometheus configuration setup script for Hyperledger Fabric monitoring
set -e

PROMETHEUS_CONFIG_DIR="/home/ubuntu/projects/monitoring/prometheus"
PROMETHEUS_CONFIG_FILE="$PROMETHEUS_CONFIG_DIR/prometheus.yml"
PROMETHEUS_PORT=9090

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Create Prometheus configuration directory
mkdir -p "$PROMETHEUS_CONFIG_DIR"

# Create Prometheus configuration file
cat > "$PROMETHEUS_CONFIG_FILE" << 'EOF'
# Prometheus configuration for Hyperledger Fabric monitoring
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Hyperledger Fabric nodes
  - job_name: 'hyperledger-fabric'
    static_configs:
      - targets: 
          - 'peer0.org1.example.com:9443'
          - 'peer0.org2.example.com:9444'
          - 'orderer.example.com:9445'
    scrape_interval: 5s
    metrics_path: '/metrics'

  # Docker containers metrics (if cAdvisor is running)
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8081']

  # Node exporter for system metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  # Custom monitoring service
  - job_name: 'monitoring-service'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'
    scrape_interval: 10s

  # Unified dashboard metrics
  - job_name: 'unified-dashboard'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/api/metrics'
    scrape_interval: 15s
EOF

# Create Docker Compose override for Prometheus
cat > "$PROMETHEUS_CONFIG_DIR/docker-compose.prometheus.yml" << 'EOF'
version: '3.7'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: fabric-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - fabric

  grafana:
    image: grafana/grafana:latest
    container_name: fabric-grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/prometheus/grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
    networks:
      - fabric

  node-exporter:
    image: prom/node-exporter:latest
    container_name: fabric-node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - fabric

volumes:
  prometheus_data:
  grafana_data:

networks:
  fabric:
    external: true
EOF

# Create Grafana datasource configuration
cat > "$PROMETHEUS_CONFIG_DIR/grafana-datasources.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create Prometheus startup script
cat > "$PROMETHEUS_CONFIG_DIR/start-prometheus.sh" << 'EOF'
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
EOF

chmod +x "$PROMETHEUS_CONFIG_DIR/start-prometheus.sh"

# Create Prometheus stop script
cat > "$PROMETHEUS_CONFIG_DIR/stop-prometheus.sh" << 'EOF'
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
EOF

chmod +x "$PROMETHEUS_CONFIG_DIR/stop-prometheus.sh"

log "✅ Prometheus configuration created successfully!"
success "📁 Configuration directory: $PROMETHEUS_CONFIG_DIR"
success "⚙️  Prometheus config: $PROMETHEUS_CONFIG_FILE"
success "🐳 Docker Compose file: $PROMETHEUS_CONFIG_DIR/docker-compose.prometheus.yml"
success "🚀 Start script: $PROMETHEUS_CONFIG_DIR/start-prometheus.sh"
success "🛑 Stop script: $PROMETHEUS_CONFIG_DIR/stop-prometheus.sh"

echo ""
echo "To start Prometheus monitoring:"
echo "  ./monitoring/prometheus/start-prometheus.sh"
echo ""
echo "To stop Prometheus monitoring:"
echo "  ./monitoring/prometheus/stop-prometheus.sh"
