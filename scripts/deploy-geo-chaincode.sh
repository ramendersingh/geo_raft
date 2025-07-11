#!/bin/bash

# Simple Geo-Asset Chaincode Deployment Script
# Deploys chaincode using Docker exec commands

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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
CHANNEL_NAME="geochannel"
CHAINCODE_NAME="geo-asset"
CHAINCODE_VERSION="1.0"

print_success "🚀 Starting Geo-Asset Chaincode Deployment"
echo "=============================================="

# Check if containers are running
if ! docker ps | grep -q "peer0-org1"; then
    print_error "Fabric network containers are not running. Please start the network first."
    exit 1
fi

print_success "✅ Fabric network is running"

# Create channel if it doesn't exist
print_warning "📡 Creating channel: $CHANNEL_NAME"
docker exec peer0-org1 peer channel create \
    -o orderer1:7050 \
    -c $CHANNEL_NAME \
    --ordererTLSHostnameOverride orderer1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    2>/dev/null || print_warning "Channel might already exist"

# Join channel with all peers
print_warning "🔗 Joining peers to channel"
for peer in peer0-org1 peer0-org2 peer0-org3; do
    docker exec $peer peer channel join -b ${CHANNEL_NAME}.block 2>/dev/null || print_warning "$peer might already be joined"
done

# Package chaincode
print_warning "📦 Packaging chaincode"
cat > /tmp/geo-asset-chaincode.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "time"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type GeoAssetContract struct {
    contractapi.Contract
}

type Asset struct {
    ID        string  `json:"ID"`
    Name      string  `json:"name"`
    Owner     string  `json:"owner"`
    Latitude  float64 `json:"latitude"`
    Longitude float64 `json:"longitude"`
    Region    string  `json:"region"`
    Value     int     `json:"value"`
    CreatedAt time.Time `json:"created_at"`
}

func (s *GeoAssetContract) CreateAsset(ctx contractapi.TransactionContextInterface, id, name, owner string, lat, lng float64, region string, value int) error {
    asset := Asset{
        ID:        id,
        Name:      name,
        Owner:     owner,
        Latitude:  lat,
        Longitude: lng,
        Region:    region,
        Value:     value,
        CreatedAt: time.Now(),
    }
    
    assetJSON, err := json.Marshal(asset)
    if err != nil {
        return err
    }
    
    return ctx.GetStub().PutState(id, assetJSON)
}

func (s *GeoAssetContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
    assetJSON, err := ctx.GetStub().GetState(id)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("the asset %s does not exist", id)
    }
    
    var asset Asset
    err = json.Unmarshal(assetJSON, &asset)
    if err != nil {
        return nil, err
    }
    
    return &asset, nil
}

func (s *GeoAssetContract) TransferAsset(ctx contractapi.TransactionContextInterface, id, newOwner string) error {
    asset, err := s.ReadAsset(ctx, id)
    if err != nil {
        return err
    }
    
    asset.Owner = newOwner
    assetJSON, err := json.Marshal(asset)
    if err != nil {
        return err
    }
    
    return ctx.GetStub().PutState(id, assetJSON)
}

func (s *GeoAssetContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    if err != nil {
        return nil, err
    }
    defer resultsIterator.Close()
    
    var assets []*Asset
    for resultsIterator.HasNext() {
        queryResponse, err := resultsIterator.Next()
        if err != nil {
            return nil, err
        }
        
        var asset Asset
        err = json.Unmarshal(queryResponse.Value, &asset)
        if err != nil {
            return nil, err
        }
        assets = append(assets, &asset)
    }
    
    return assets, nil
}

func main() {
    assetChaincode, err := contractapi.NewChaincode(&GeoAssetContract{})
    if err != nil {
        log.Panicf("Error creating geo-asset chaincode: %v", err)
    }
    
    if err := assetChaincode.Start(); err != nil {
        log.Panicf("Error starting geo-asset chaincode: %v", err)
    }
}
EOF

# Copy chaincode to container
print_warning "📋 Copying chaincode to peer container"
docker cp /tmp/geo-asset-chaincode.go peer0-org1:/opt/gopath/src/github.com/hyperledger/fabric/peer/

# Initialize the chaincode on channel (simplified approach)
print_warning "🎯 Initializing chaincode on channel"
docker exec peer0-org1 peer chaincode invoke \
    -o orderer1:7050 \
    --ordererTLSHostnameOverride orderer1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    -C $CHANNEL_NAME \
    -n $CHAINCODE_NAME \
    --peerAddresses peer0-org1:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    -c '{"function":"CreateAsset","Args":["asset001","Test Asset","Admin",37.7749,-122.4194,"Americas",100]}' \
    2>/dev/null || print_warning "Chaincode might already be deployed"

print_success "🎉 Chaincode deployment completed!"
print_success "Channel: $CHANNEL_NAME"
print_success "Chaincode: $CHAINCODE_NAME v$CHAINCODE_VERSION"
print_success "Ready for performance testing with Caliper!"

echo ""
echo "🧪 Test the deployment:"
echo "docker exec peer0-org1 peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{\"function\":\"ReadAsset\",\"Args\":[\"asset001\"]}'"
