#!/bin/bash

# Generate metrics activity for demonstration
# This script queries the Fabric services to generate some activity

echo "🔄 Generating network activity to populate metrics..."

# Query orderer status
echo "📊 Checking orderer status..."
curl -s "http://localhost:17050/healthz" > /dev/null 2>&1 || echo "Orderer1 healthcheck"
curl -s "http://localhost:18050/healthz" > /dev/null 2>&1 || echo "Orderer2 healthcheck"
curl -s "http://localhost:19050/healthz" > /dev/null 2>&1 || echo "Orderer3 healthcheck"

# Query peer status
echo "🔗 Checking peer status..."
curl -s "http://localhost:9443/healthz" > /dev/null 2>&1 || echo "Peer1 healthcheck"
curl -s "http://localhost:9444/healthz" > /dev/null 2>&1 || echo "Peer2 healthcheck"
curl -s "http://localhost:9445/healthz" > /dev/null 2>&1 || echo "Peer3 healthcheck"

# Check prometheus metrics directly
echo "📈 Verifying metrics collection..."
ACTIVE_SERVICES=$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq -r '.data.result | length')
echo "✅ Found $ACTIVE_SERVICES services being monitored"

echo "🎉 Activity generated! Check Grafana dashboard at http://localhost:3000"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "Look for 'Geo-Aware Fabric Network Monitor' dashboard"
