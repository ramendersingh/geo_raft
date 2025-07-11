# Deployment Guide

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu 20.04+ or CentOS 8+
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **CPU**: 4+ cores
- **Storage**: 100GB+ free space
- **Network**: Stable internet connection

### Software Dependencies
- **Docker**: 20.10+
- **Docker Compose**: v2.0+
- **Node.js**: 16.0+
- **Go**: 1.19+ (for chaincode development)
- **Git**: Latest version

## Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd fabric-geo-consensus
```

### 2. Setup Network
```bash
./scripts/setup-network.sh
```

### 3. Start Network
```bash
docker compose up -d
```

### 4. Access Dashboard
Open http://localhost:8080 in your browser.

## Detailed Setup

### Environment Preparation

#### Install Docker
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Log out and log back in for group changes to take effect
```

#### Install Docker Compose v2
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### Install Node.js
```bash
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### Install Go (Optional)
```bash
wget https://go.dev/dl/go1.19.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### Network Configuration

#### Custom Network Configuration

Edit `docker-compose.yml` to customize:

1. **Geographic Locations**: Update environment variables for each orderer:
```yaml
environment:
  - GEO_LOCATION_LATITUDE=37.7749
  - GEO_LOCATION_LONGITUDE=-122.4194
  - GEO_LOCATION_REGION=us-west
  - GEO_LOCATION_ZONE=us-west-1a
```

2. **Consensus Parameters**: Modify etcdraft settings:
```yaml
environment:
  - ORDERER_CONSENSUS_ETCDRAFT_TICKINTERVAL=500ms
  - ORDERER_CONSENSUS_ETCDRAFT_ELECTIONTICK=10
  - ORDERER_CONSENSUS_ETCDRAFT_HEARTBEATTICK=1
```

3. **Network Ports**: Ensure ports are available:
   - Orderers: 7050, 8050, 9050
   - Peers: 7051, 9051, 11051
   - Dashboard: 8080
   - Grafana: 3000
   - Prometheus: 9090

### Custom Regions Setup

To add new geographic regions:

1. **Update Docker Compose**:
```yaml
orderer4:
  image: hyperledger/fabric-orderer:latest
  environment:
    # ... standard orderer config
    - GEO_LOCATION_LATITUDE=35.6762
    - GEO_LOCATION_LONGITUDE=139.6503
    - GEO_LOCATION_REGION=asia-northeast
    - GEO_LOCATION_ZONE=asia-northeast-1a
```

2. **Update configtx.yaml**:
```yaml
EtcdRaft:
  Consenters:
  # ... existing consenters
  - Host: orderer4.example.com
    Port: 10050
    ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt
    ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt
```

3. **Update Monitoring**:
Add new regions to Prometheus and dashboard configuration.

## Production Deployment

### Security Considerations

1. **TLS Configuration**:
   - Enable TLS for all communications
   - Use valid certificates in production
   - Configure mutual TLS authentication

2. **Firewall Settings**:
```bash
# Allow required ports
sudo ufw allow 7050  # Orderer1
sudo ufw allow 8050  # Orderer2
sudo ufw allow 9050  # Orderer3
sudo ufw allow 7051  # Peer Org1
sudo ufw allow 9051  # Peer Org2
sudo ufw allow 11051 # Peer Org3
```

3. **Access Control**:
   - Restrict dashboard access
   - Use proper MSP configuration
   - Implement API authentication

### Performance Tuning

#### Orderer Optimization
```yaml
environment:
  # Batch size optimization
  - ORDERER_GENERAL_BATCHSIZE_MAXMESSAGECOUNT=500
  - ORDERER_GENERAL_BATCHSIZE_ABSOLUTEMAXBYTES=10MB
  - ORDERER_GENERAL_BATCHSIZE_PREFERREDMAXBYTES=2MB
  
  # Timeout optimization
  - ORDERER_GENERAL_BATCHTIMEOUT=1s
  
  # Consensus optimization
  - ORDERER_CONSENSUS_ETCDRAFT_TICKINTERVAL=250ms
  - ORDERER_CONSENSUS_ETCDRAFT_ELECTIONTICK=20
  - ORDERER_CONSENSUS_ETCDRAFT_HEARTBEATTICK=2
```

#### Peer Optimization
```yaml
environment:
  # Cache and database
  - CORE_PEER_GOSSIP_STATE_CHECKINTERVAL=10s
  - CORE_PEER_GOSSIP_STATE_RESPONSEBATCHSIZE=100
  
  # Chaincode execution
  - CORE_CHAINCODE_EXECUTETIMEOUT=120s
  - CORE_CHAINCODE_STARTUPTIMEOUT=60s
```

### Monitoring Setup

#### Prometheus Configuration
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 10s
  evaluation_interval: 10s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'fabric-orderers'
    static_configs:
      - targets: ['orderer1:17050', 'orderer2:18050', 'orderer3:19050']
    scrape_interval: 5s
    
  - job_name: 'fabric-peers'
    static_configs:
      - targets: ['peer0-org1:9443', 'peer0-org2:9444', 'peer0-org3:9445']
    scrape_interval: 5s
```

#### Grafana Dashboards
```yaml
# monitoring/grafana/provisioning/dashboards/dashboard.yml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

### High Availability

#### Multi-Region Deployment
```yaml
# Production multi-region setup
version: '3.8'

services:
  # US West Region
  orderer-usw-1:
    deploy:
      placement:
        constraints:
          - node.labels.region == us-west
  
  # US East Region  
  orderer-use-1:
    deploy:
      placement:
        constraints:
          - node.labels.region == us-east
  
  # EU West Region
  orderer-euw-1:
    deploy:
      placement:
        constraints:
          - node.labels.region == eu-west
```

#### Load Balancing
```yaml
# nginx.conf for load balancing
upstream fabric_orderers {
    least_conn;
    server orderer1:7050 weight=3;
    server orderer2:8050 weight=2;
    server orderer3:9050 weight=1;
}

server {
    listen 7050;
    proxy_pass fabric_orderers;
}
```

### Backup and Recovery

#### Database Backup
```bash
#!/bin/bash
# backup-script.sh

BACKUP_DIR="/backup/fabric-$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup orderer data
for orderer in orderer1 orderer2 orderer3; do
    docker run --rm -v ${orderer}-data:/data -v $BACKUP_DIR:/backup alpine \
        tar czf /backup/${orderer}-data.tar.gz -C /data .
done

# Backup peer data
for peer in peer0-org1 peer0-org2 peer0-org3; do
    docker run --rm -v ${peer}-data:/data -v $BACKUP_DIR:/backup alpine \
        tar czf /backup/${peer}-data.tar.gz -C /data .
done
```

#### Configuration Backup
```bash
# Backup crypto material and configurations
tar czf crypto-config-backup.tar.gz network/crypto-config/
tar czf channel-artifacts-backup.tar.gz network/channel-artifacts/
```

### Troubleshooting

#### Common Issues

1. **Port Conflicts**:
```bash
# Check port usage
netstat -tulpn | grep :7050
lsof -i :7050
```

2. **Certificate Issues**:
```bash
# Regenerate certificates
rm -rf network/crypto-config/
./bin/cryptogen generate --config=network/crypto-config.yaml --output="network/crypto-config"
```

3. **Docker Issues**:
```bash
# Clean Docker environment
docker compose down -v
docker system prune -f
docker volume prune -f
```

#### Log Analysis
```bash
# View orderer logs
docker logs orderer1 --tail 100 -f

# View peer logs
docker logs peer0-org1 --tail 100 -f

# View dashboard logs
docker logs geo-dashboard --tail 100 -f
```

### Scaling Guidelines

#### Horizontal Scaling
- Add orderers in different geographic regions
- Increase peer count per organization
- Implement multiple channels for different use cases

#### Vertical Scaling
- Increase CPU and memory allocation
- Use faster storage (SSD)
- Optimize network bandwidth

### Maintenance

#### Regular Tasks
1. Monitor disk space and clean old logs
2. Update Docker images regularly
3. Backup configuration and data
4. Monitor performance metrics
5. Review security logs

#### Updates
```bash
# Update Docker images
docker compose pull
docker compose up -d

# Update Node.js dependencies
npm update

# Update monitoring stack
docker compose -f monitoring/docker-compose.yml pull
```
