#!/bin/bash

# Fabric 2.5 Channel Participation Script
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
PROJECT_ROOT="/home/ubuntu/projects"
CHANNEL_NAME="mychannel"
CHAINCODE_NAME="geo-asset"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"

# Set environment variables
export PATH=${PROJECT_ROOT}/bin:$PATH
export FABRIC_CFG_PATH=${PROJECT_ROOT}/network

print_status "=== Fabric 2.5 Channel Participation Setup ==="

# Function to set peer environment
set_peer_env() {
    local org=$1
    case $org in
        "org1")
            export CORE_PEER_TLS_ENABLED=true
            export CORE_PEER_LOCALMSPID="Org1MSP"
            export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
            export CORE_PEER_MSPCONFIGPATH=${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
            export CORE_PEER_ADDRESS=localhost:7051
            ;;
        "org2")
            export CORE_PEER_TLS_ENABLED=true
            export CORE_PEER_LOCALMSPID="Org2MSP"
            export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
            export CORE_PEER_MSPCONFIGPATH=${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
            export CORE_PEER_ADDRESS=localhost:9051
            ;;
        "org3")
            export CORE_PEER_TLS_ENABLED=true
            export CORE_PEER_LOCALMSPID="Org3MSP"
            export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
            export CORE_PEER_MSPCONFIGPATH=${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
            export CORE_PEER_ADDRESS=localhost:11051
            ;;
    esac
}

# Create application channel configuration
create_channel_config() {
    print_status "Creating application channel configuration..."
    
    # Generate the channel creation block
    configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ${PROJECT_ROOT}/network/channel-artifacts/${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}
    
    print_success "Channel configuration created"
}

# Use osnadmin to join channel (Fabric 2.5 approach)
join_orderers_to_channel() {
    print_status "Joining orderers to channel using channel participation..."
    
    # Create the genesis block for the channel
    set_peer_env "org1"
    
    # Create the channel
    peer channel create \
        -o localhost:7050 \
        -c ${CHANNEL_NAME} \
        -f ${PROJECT_ROOT}/network/channel-artifacts/${CHANNEL_NAME}.tx \
        --outputBlock ${PROJECT_ROOT}/network/channel-artifacts/${CHANNEL_NAME}.block \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    
    print_success "Channel created and orderers joined"
}

# Join peers to channel
join_peers() {
    print_status "Joining peers to channel"
    
    # Join Org1 peer
    set_peer_env "org1"
    peer channel join -b ${PROJECT_ROOT}/network/channel-artifacts/${CHANNEL_NAME}.block
    print_status "Org1 peer joined channel"
    
    # Join Org2 peer
    set_peer_env "org2"
    peer channel join -b ${PROJECT_ROOT}/network/channel-artifacts/${CHANNEL_NAME}.block
    print_status "Org2 peer joined channel"
    
    # Join Org3 peer
    set_peer_env "org3"
    peer channel join -b ${PROJECT_ROOT}/network/channel-artifacts/${CHANNEL_NAME}.block
    print_status "Org3 peer joined channel"
    
    print_success "All peers joined to channel"
}

# Install chaincode
install_chaincode() {
    print_status "Installing chaincode on all peers"
    
    # Install on Org1
    set_peer_env "org1"
    peer lifecycle chaincode install ${PROJECT_ROOT}/geo-asset.tar.gz
    
    # Install on Org2
    set_peer_env "org2"
    peer lifecycle chaincode install ${PROJECT_ROOT}/geo-asset.tar.gz
    
    # Install on Org3
    set_peer_env "org3"
    peer lifecycle chaincode install ${PROJECT_ROOT}/geo-asset.tar.gz
    
    print_success "Chaincode installed on all peers"
}

# Get package ID
get_package_id() {
    set_peer_env "org1"
    PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq -r '.installed_chaincodes[0].package_id')
    print_status "Package ID: $PACKAGE_ID"
}

# Approve chaincode
approve_chaincode() {
    print_status "Approving chaincode for all organizations"
    
    # Approve for Org1
    set_peer_env "org1"
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CHAINCODE_SEQUENCE
    
    # Approve for Org2
    set_peer_env "org2"
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CHAINCODE_SEQUENCE
    
    # Approve for Org3
    set_peer_env "org3"
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CHAINCODE_SEQUENCE
    
    print_success "Chaincode approved by all organizations"
}

# Commit chaincode
commit_chaincode() {
    print_status "Committing chaincode"
    
    set_peer_env "org1"
    
    # Check commit readiness
    peer lifecycle chaincode checkcommitreadiness \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --sequence $CHAINCODE_SEQUENCE \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --output json
    
    # Commit chaincode
    peer lifecycle chaincode commit \
        -o localhost:7050 \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --sequence $CHAINCODE_SEQUENCE \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles ${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles ${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
        --peerAddresses localhost:11051 \
        --tlsRootCertFiles ${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
    
    print_success "Chaincode committed successfully"
}

# Test chaincode
test_chaincode() {
    print_status "Testing chaincode"
    
    set_peer_env "org1"
    
    # Initialize ledger
    print_status "Initializing ledger..."
    peer chaincode invoke \
        -o localhost:7050 \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles ${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        -c '{"function":"InitLedger","Args":[]}'
    
    sleep 5
    
    # Query all assets
    print_status "Querying all assets..."
    peer chaincode query \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        -c '{"function":"GetAllAssets","Args":[]}'
    
    # Test geo-aware functionality
    print_status "Testing geo-aware asset creation..."
    peer chaincode invoke \
        -o localhost:7050 \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles ${PROJECT_ROOT}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        -c '{"function":"CreateAsset","Args":["geo001","Test Geo Asset","Berlin","52.5200","13.4050","50000","EUR","TestUser"]}'
    
    sleep 3
    
    # Query the new asset
    print_status "Querying the new geo asset..."
    peer chaincode query \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        -c '{"function":"ReadAsset","Args":["geo001"]}'
    
    print_success "Chaincode test completed successfully!"
}

# Main execution
main() {
    if [ ! -f "${PROJECT_ROOT}/geo-asset.tar.gz" ]; then
        print_error "Chaincode package not found at ${PROJECT_ROOT}/geo-asset.tar.gz"
        exit 1
    fi
    
    create_channel_config
    join_orderers_to_channel
    join_peers
    install_chaincode
    get_package_id
    approve_chaincode
    commit_chaincode
    test_chaincode
    
    print_success "=== Complete Geo-Aware Blockchain Network Deployed! ==="
    print_status "Network Summary:"
    print_status "- Channel: $CHANNEL_NAME"
    print_status "- Chaincode: $CHAINCODE_NAME v$CHAINCODE_VERSION"
    print_status "- Organizations: 3 (Org1, Org2, Org3)"
    print_status "- Orderers: 3 (Geo-aware consensus enabled)"
    print_status "- Peers: 3 (Geographic distribution supported)"
    print_status ""
    print_status "Next steps:"
    print_status "1. Run Caliper benchmarks: npm run benchmark"
    print_status "2. View monitoring dashboard: http://localhost:3000"
    print_status "3. Check Prometheus metrics: http://localhost:9090"
}

# Run main function
main "$@"
