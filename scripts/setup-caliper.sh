#!/bin/bash

echo "⚙️  SETTING UP CALIPER BENCHMARKING..."
echo "====================================="

# Check if Caliper CLI is installed
echo "1️⃣ Checking Caliper CLI installation..."
if ! command -v caliper &> /dev/null; then
    echo "📦 Installing Caliper CLI..."
    npm install -g @hyperledger/caliper-cli@0.5.0
else
    echo "✅ Caliper CLI already installed"
fi

# Setup Caliper workspace
echo "2️⃣ Setting up Caliper workspace..."
cd caliper || exit 1

# Check if binding is needed
if [ ! -d "node_modules" ] || [ ! -f "package.json" ]; then
    echo "🔗 Binding Caliper to Fabric 2.2..."
    caliper bind --caliper-bind-sut fabric:2.2 --caliper-bind-cwd ./ || {
        echo "❌ Failed to bind Caliper to Fabric"
        exit 1
    }
else
    echo "✅ Caliper already bound"
fi

# Verify network configuration
echo "3️⃣ Verifying network configuration..."
if [ -f "network-config.yaml" ]; then
    echo "✅ Network config exists"
else
    echo "❌ Network config missing"
    exit 1
fi

# Check benchmark configuration
echo "4️⃣ Checking benchmark configuration..."
if [ -f "benchmark-config.yaml" ]; then
    echo "✅ Benchmark config exists"
else
    echo "❌ Benchmark config missing"
    exit 1
fi

# Validate workload files
echo "5️⃣ Validating workload files..."
if [ -d "workload" ] && [ "$(ls -A workload)" ]; then
    echo "✅ Workload files exist"
else
    echo "❌ Workload files missing"
    exit 1
fi

# Check if Fabric network is running
echo "6️⃣ Checking Fabric network status..."
cd .. || exit 1
if docker ps | grep -q "peer0-org1"; then
    echo "✅ Fabric network is running"
else
    echo "⚠️  Fabric network not running. Starting it..."
    docker compose up -d
    sleep 10
fi

# Test connection to peers
echo "7️⃣ Testing peer connectivity..."
PEER_STATUS=$(docker ps --filter "name=peer0-org1" --format "{{.Status}}")
if [[ "$PEER_STATUS" == *"Up"* ]]; then
    echo "✅ Peers are accessible"
else
    echo "❌ Peers not accessible"
    exit 1
fi

echo ""
echo "🎉 CALIPER SETUP COMPLETE!"
echo "========================="
echo "✅ Caliper CLI installed"
echo "✅ Fabric binding configured"
echo "✅ Network configuration validated"
echo "✅ Benchmark configuration ready"
echo "✅ Fabric network running"
echo ""
echo "🚀 Ready to run benchmarks!"
echo "Use: ./scripts/run-caliper-benchmark.sh"
