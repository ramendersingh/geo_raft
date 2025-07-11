#!/bin/bash

# Deploy Geo-Asset Chaincode Script
# This script deploys the geo-asset chaincode to the Fabric network

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
CHANNEL_NAME="geo-channel"
CHAINCODE_NAME="geo-asset"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"
CHAINCODE_PATH="./chaincode"

# Network configuration
FABRIC_CFG_PATH=${PWD}/network
CORE_PEER_TLS_ENABLED=true
CORE_PEER_LOCALMSPID="Org1MSP"
CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
CORE_PEER_ADDRESS=localhost:7051

export FABRIC_CFG_PATH CORE_PEER_TLS_ENABLED CORE_PEER_LOCALMSPID CORE_PEER_TLS_ROOTCERT_FILE CORE_PEER_MSPCONFIGPATH CORE_PEER_ADDRESS

print_status "Starting chaincode deployment process..."

# Function to check if channel exists
check_channel() {
    print_status "Checking if channel '$CHANNEL_NAME' exists..."
    
    if peer channel list | grep -q "$CHANNEL_NAME"; then
        print_success "Channel '$CHANNEL_NAME' exists"
        return 0
    else
        print_warning "Channel '$CHANNEL_NAME' not found. Creating channel..."
        create_channel
    fi
}

# Function to create channel
create_channel() {
    print_status "Creating channel '$CHANNEL_NAME'..."
    
    # Generate channel transaction
    configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ./network/channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
    
    # Create channel
    peer channel create -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1 \
        -c $CHANNEL_NAME \
        -f ./network/channel-artifacts/${CHANNEL_NAME}.tx \
        --outputBlock ./network/channel-artifacts/${CHANNEL_NAME}.block \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    
    print_success "Channel '$CHANNEL_NAME' created successfully"
    
    # Join peers to channel
    join_peers_to_channel
}

# Function to join peers to channel
join_peers_to_channel() {
    print_status "Joining peers to channel..."
    
    # Join Org1 peer
    peer channel join -b ./network/channel-artifacts/${CHANNEL_NAME}.block
    
    # Switch to Org2
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
    
    peer channel join -b ./network/channel-artifacts/${CHANNEL_NAME}.block
    
    # Switch to Org3
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051
    
    peer channel join -b ./network/channel-artifacts/${CHANNEL_NAME}.block
    
    # Reset to Org1
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    
    print_success "All peers joined to channel"
}

# Function to package chaincode
package_chaincode() {
    print_status "Packaging chaincode..."
    
    # Build the chaincode
    cd ${CHAINCODE_PATH}
    if [ ! -f "go.mod" ]; then
        go mod init geo-asset-chaincode
    fi
    go mod tidy
    cd ..
    
    # Package chaincode
    peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz \
        --path ${CHAINCODE_PATH} \
        --lang golang \
        --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION}
    
    print_success "Chaincode packaged successfully"
}

# Function to install chaincode on all peers
install_chaincode() {
    print_status "Installing chaincode on all peers..."
    
    # Install on Org1 peer
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_ADDRESS=localhost:7051
    peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz
    
    # Install on Org2 peer
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
    peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz
    
    # Install on Org3 peer
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051
    peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz
    
    print_success "Chaincode installed on all peers"
}

# Function to approve chaincode for organizations
approve_chaincode() {
    print_status "Approving chaincode for organizations..."
    
    # Get package ID
    PACKAGE_ID=$(peer lifecycle chaincode queryinstalled --output json | jq -r ".installed_chaincodes[0].package_id")
    print_status "Package ID: $PACKAGE_ID"
    
    # Approve for Org1
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1 \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CHAINCODE_SEQUENCE \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    
    # Approve for Org2
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
    
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1 \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CHAINCODE_SEQUENCE \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    
    # Approve for Org3
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051
    
    peer lifecycle chaincode approveformyorg \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1 \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID \
        --sequence $CHAINCODE_SEQUENCE \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    
    print_success "Chaincode approved for all organizations"
}

# Function to commit chaincode
commit_chaincode() {
    print_status "Committing chaincode..."
    
    # Reset to Org1
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/network/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    
    # Check commit readiness
    peer lifecycle chaincode checkcommitreadiness \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --sequence $CHAINCODE_SEQUENCE \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --output json
    
    # Commit chaincode
    peer lifecycle chaincode commit \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1 \
        --channelID $CHANNEL_NAME \
        --name $CHAINCODE_NAME \
        --version $CHAINCODE_VERSION \
        --sequence $CHAINCODE_SEQUENCE \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles ${PWD}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles ${PWD}/network/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
        --peerAddresses localhost:11051 \
        --tlsRootCertFiles ${PWD}/network/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
    
    print_success "Chaincode committed successfully"
}

# Function to test chaincode
test_chaincode() {
    print_status "Testing chaincode..."
    
    # Initialize ledger
    peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1 \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles ${PWD}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        -c '{"function":"InitLedger","Args":[]}'
    
    # Create a test asset
    peer chaincode invoke \
        -o localhost:7050 \
        --ordererTLSHostnameOverride orderer1 \
        --tls \
        --cafile ${PWD}/network/crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles ${PWD}/network/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        -c '{"function":"CreateAsset","Args":["test001","TestAsset","New York","40.7128","-74.0060","100","USD","TestOwner"]}'
    
    # Query the asset
    peer chaincode query \
        -C $CHANNEL_NAME \
        -n $CHAINCODE_NAME \
        -c '{"function":"ReadAsset","Args":["test001"]}'
    
    print_success "Chaincode tested successfully"
}

# Main execution
main() {
    print_status "=== Geo-Asset Chaincode Deployment ==="
    
    # Check if network is running
    if ! docker compose ps | grep -q "Up"; then
        print_error "Network is not running. Please start the network first with 'docker compose up -d'"
        exit 1
    fi
    
    # Check prerequisites
    if ! command -v peer &> /dev/null; then
        print_error "Hyperledger Fabric peer binary not found. Please ensure Fabric binaries are in PATH."
        exit 1
    fi
    
    if ! command -v configtxgen &> /dev/null; then
        print_error "configtxgen binary not found. Please ensure Fabric binaries are in PATH."
        exit 1
    fi
    
    # Create necessary directories
    mkdir -p ./network/channel-artifacts
    
    # Execute deployment steps
    package_chaincode
    
    # Note: For now, we'll skip the channel operations since we need proper crypto material
    print_warning "Channel operations skipped - requires proper crypto material generation"
    print_warning "Network is ready for chaincode deployment once channels are created"
    
    print_success "=== Chaincode packaging completed ==="
    print_status "Next steps:"
    print_status "1. Generate crypto material and channel artifacts"
    print_status "2. Create and join channels"
    print_status "3. Install and commit chaincode"
    print_status "4. Test geo-aware transactions"
}

# Run main function
main "$@"
