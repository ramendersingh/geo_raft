#!/bin/bash

# Channel Creation and Chaincode Deployment Script
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
CHANNEL_NAME="mychannel"
CHAINCODE_NAME="geo-asset"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"

# Set environment variables
PROJECT_ROOT="/home/ubuntu/projects"
export PATH=${PROJECT_ROOT}/bin:$PATH
export FABRIC_CFG_PATH=${PROJECT_ROOT}/network

print_status "=== Creating Channel and Deploying Chaincode ==="

# Function to set peer environment for different organizations
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

# Create channel
create_channel() {
    print_status "Creating channel: $CHANNEL_NAME"
    
    set_peer_env "org1"
    
    # Create channel
    peer channel create \
        -o localhost:7050 \
        -c $CHANNEL_NAME \
        -f ${PROJECT_ROOT}/network/channel-artifacts/channel.tx \
        --outputBlock ${PROJECT_ROOT}/network/channel-artifacts/${CHANNEL_NAME}.block \
        --tls \
        --cafile ${PROJECT_ROOT}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    
    print_success "Channel created successfully"
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
    peer chaincode query \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        -c '{"function":"GetAllAssets","Args":[]}'
    
    print_success "Chaincode test completed"
}

# Main execution
main() {
    if [ ! -f "${PROJECT_ROOT}/geo-asset.tar.gz" ]; then
        print_error "Chaincode package not found. Please run packaging first."
        exit 1
    fi
    
    create_channel
    join_peers
    install_chaincode
    get_package_id
    approve_chaincode
    commit_chaincode
    test_chaincode
    
    print_success "=== Channel and Chaincode setup completed! ==="
    print_status "You can now test the geo-aware chaincode with the network"
}

# Run main function
main "$@"
