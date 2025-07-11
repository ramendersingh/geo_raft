#!/bin/bash

# Hyperledger Fabric Geo-Consensus Network Setup Script
# This script sets up the complete geo-aware consensus network

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FABRIC_VERSION="2.5.4"
CA_VERSION="1.5.6"
NETWORK_NAME="fabric-geo-network"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE} Hyperledger Fabric Geo-Consensus Setup  ${NC}"
echo -e "${BLUE}===========================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        print_error "Docker Compose v2 is not available. Please install Docker Compose v2."
        exit 1
    fi
    
    # Check Go
    if ! command -v go &> /dev/null; then
        print_warning "Go is not installed. Some features may not work."
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_warning "Node.js is not installed. Caliper benchmarks may not work."
    fi
    
    print_status "Prerequisites check completed."
}

# Download Fabric binaries
download_fabric_binaries() {
    print_status "Downloading Hyperledger Fabric binaries..."
    
    if [ ! -d "bin" ]; then
        curl -sSL https://bit.ly/2ysbOFE | bash -s -- ${FABRIC_VERSION} ${CA_VERSION} -d -s
        
        # Make sure binaries are in PATH
        export PATH=$PWD/bin:$PATH
        echo 'export PATH=$PWD/bin:$PATH' >> ~/.bashrc
        
        print_status "Fabric binaries downloaded successfully."
    else
        print_status "Fabric binaries already exist."
    fi
}

# Generate crypto material
generate_crypto_material() {
    print_status "Generating crypto material..."
    
    # Create network directory structure
    mkdir -p network/{crypto-config,channel-artifacts,configtx}
    
    # Create crypto-config.yaml
    cat > network/crypto-config.yaml << EOF
OrdererOrgs:
  - Name: Orderer
    Domain: example.com
    EnableNodeOUs: true
    Specs:
      - Hostname: orderer1
        SANS:
          - localhost
          - orderer1
          - orderer1.example.com
      - Hostname: orderer2
        SANS:
          - localhost
          - orderer2
          - orderer2.example.com
      - Hostname: orderer3
        SANS:
          - localhost
          - orderer3
          - orderer3.example.com

PeerOrgs:
  - Name: Org1
    Domain: org1.example.com
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
        - peer0.org1.example.com
    Users:
      Count: 1

  - Name: Org2
    Domain: org2.example.com
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
        - peer0.org2.example.com
    Users:
      Count: 1

  - Name: Org3
    Domain: org3.example.com
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
        - peer0.org3.example.com
    Users:
      Count: 1
EOF

    # Generate crypto material
    if [ ! -d "network/crypto-config" ] || [ -z "$(ls -A network/crypto-config)" ]; then
        ./bin/cryptogen generate --config=network/crypto-config.yaml --output="network/crypto-config"
        print_status "Crypto material generated successfully."
    else
        print_status "Crypto material already exists."
    fi
}

# Create configtx.yaml
create_configtx() {
    print_status "Creating configtx.yaml..."
    
    cat > network/configtx.yaml << EOF
Organizations:
    - &OrdererOrg
        Name: OrdererOrg
        ID: OrdererMSP
        MSPDir: crypto-config/ordererOrganizations/example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Writers:
                Type: Signature
                Rule: "OR('OrdererMSP.member')"
            Admins:
                Type: Signature
                Rule: "OR('OrdererMSP.admin')"

    - &Org1
        Name: Org1MSP
        ID: Org1MSP
        MSPDir: crypto-config/peerOrganizations/org1.example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org1MSP.admin', 'Org1MSP.peer', 'Org1MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org1MSP.admin', 'Org1MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org1MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org1MSP.peer')"
        AnchorPeers:
            - Host: peer0.org1.example.com
              Port: 7051

    - &Org2
        Name: Org2MSP
        ID: Org2MSP
        MSPDir: crypto-config/peerOrganizations/org2.example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.peer', 'Org2MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org2MSP.admin', 'Org2MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org2MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org2MSP.peer')"
        AnchorPeers:
            - Host: peer0.org2.example.com
              Port: 9051

    - &Org3
        Name: Org3MSP
        ID: Org3MSP
        MSPDir: crypto-config/peerOrganizations/org3.example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org3MSP.admin', 'Org3MSP.peer', 'Org3MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org3MSP.admin', 'Org3MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org3MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org3MSP.peer')"
        AnchorPeers:
            - Host: peer0.org3.example.com
              Port: 11051

Capabilities:
    Channel: &ChannelCapabilities
        V2_0: true
    Orderer: &OrdererCapabilities
        V2_0: true
    Application: &ApplicationCapabilities
        V2_0: true

Application: &ApplicationDefaults
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        LifecycleEndorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
        Endorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
    Capabilities:
        <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
    OrdererType: etcdraft
    BatchTimeout: 2s
    BatchSize:
        MaxMessageCount: 10
        AbsoluteMaxBytes: 99 MB
        PreferredMaxBytes: 512 KB
    EtcdRaft:
        Consenters:
        - Host: orderer1.example.com
          Port: 7050
          ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/tls/server.crt
          ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/tls/server.crt
        - Host: orderer2.example.com
          Port: 8050
          ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt
          ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/tls/server.crt
        - Host: orderer3.example.com
          Port: 9050
          ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/tls/server.crt
          ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer3.example.com/tls/server.crt
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        BlockValidation:
            Type: ImplicitMeta
            Rule: "ANY Writers"
    Capabilities:
        <<: *OrdererCapabilities

Channel: &ChannelDefaults
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
    Capabilities:
        <<: *ChannelCapabilities

Profiles:
    ThreeOrgsOrdererGenesis:
        <<: *ChannelDefaults
        Orderer:
            <<: *OrdererDefaults
            Organizations:
                - *OrdererOrg
            Capabilities:
                <<: *OrdererCapabilities
        Consortiums:
            SampleConsortium:
                Organizations:
                    - *Org1
                    - *Org2
                    - *Org3

    ThreeOrgsChannel:
        Consortium: SampleConsortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:
                - *Org1
                - *Org2
                - *Org3
            Capabilities:
                <<: *ApplicationCapabilities
EOF

    print_status "configtx.yaml created successfully."
}

# Generate genesis block and channel artifacts
generate_channel_artifacts() {
    print_status "Generating channel artifacts..."
    
    export FABRIC_CFG_PATH=$PWD/network
    
    # Generate genesis block
    if [ ! -f "network/channel-artifacts/genesis.block" ]; then
        ./bin/configtxgen -profile ThreeOrgsOrdererGenesis -channelID system-channel -outputBlock network/channel-artifacts/genesis.block
        print_status "Genesis block generated."
    fi
    
    # Generate channel creation transaction
    if [ ! -f "network/channel-artifacts/channel.tx" ]; then
        ./bin/configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx network/channel-artifacts/channel.tx -channelID mychannel
        print_status "Channel creation transaction generated."
    fi
    
    # Generate anchor peer updates
    for org in Org1MSP Org2MSP Org3MSP; do
        if [ ! -f "network/channel-artifacts/${org}anchors.tx" ]; then
            ./bin/configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate network/channel-artifacts/${org}anchors.tx -channelID mychannel -asOrg ${org}
            print_status "Anchor peer update for ${org} generated."
        fi
    done
}

# Create monitoring configuration
create_monitoring_config() {
    print_status "Creating monitoring configuration..."
    
    mkdir -p monitoring/grafana/{dashboards,datasources}
    
    # Prometheus configuration
    cat > monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'orderer-nodes'
    static_configs:
      - targets: ['orderer1:17050', 'orderer2:18050', 'orderer3:19050']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'peer-nodes'
    static_configs:
      - targets: ['peer0-org1:9443', 'peer0-org2:9444', 'peer0-org3:9445']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'geo-consensus'
    static_configs:
      - targets: ['geo-dashboard:8080']
    metrics_path: /api/metrics
    scrape_interval: 30s
EOF

    # Grafana datasource
    cat > monitoring/grafana/datasources/datasource.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

    # Create monitoring Dockerfile
    cat > monitoring/Dockerfile << EOF
FROM node:16-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 8080

CMD ["node", "dashboard.js"]
EOF

    cat > monitoring/package.json << EOF
{
  "name": "fabric-geo-dashboard",
  "version": "1.0.0",
  "description": "Geo-aware consensus monitoring dashboard",
  "main": "dashboard.js",
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "axios": "^1.4.0"
  }
}
EOF

    print_status "Monitoring configuration created."
}

# Install Node.js dependencies
install_dependencies() {
    print_status "Installing Node.js dependencies..."
    
    if command -v npm &> /dev/null; then
        npm install
        print_status "Dependencies installed successfully."
    else
        print_warning "npm not found. Please install Node.js to run benchmarks and monitoring."
    fi
}

# Build chaincode
build_chaincode() {
    print_status "Building chaincode..."
    
    if command -v go &> /dev/null; then
        cd chaincode
        go mod init geo-asset-chaincode
        go mod tidy
        cd ..
        print_status "Chaincode built successfully."
    else
        print_warning "Go not found. Chaincode build skipped."
    fi
}

# Main execution
main() {
    print_status "Starting Hyperledger Fabric Geo-Consensus setup..."
    
    check_prerequisites
    download_fabric_binaries
    generate_crypto_material
    create_configtx
    generate_channel_artifacts
    create_monitoring_config
    install_dependencies
    build_chaincode
    
    print_status "Setup completed successfully!"
    echo -e "${GREEN}===========================================${NC}"
    echo -e "${GREEN} Setup Complete! Next Steps:             ${NC}"
    echo -e "${GREEN}===========================================${NC}"
    echo -e "${YELLOW}1. Start the network:${NC}"
    echo -e "   docker compose up -d"
    echo -e ""
    echo -e "${YELLOW}2. Access the dashboard:${NC}"
    echo -e "   http://localhost:8080"
    echo -e ""
    echo -e "${YELLOW}3. Monitor with Grafana:${NC}"
    echo -e "   http://localhost:3000 (admin/admin)"
    echo -e ""
    echo -e "${YELLOW}4. Run benchmarks:${NC}"
    echo -e "   npm run caliper-benchmark"
    echo -e ""
}

# Execute main function
main "$@"
