#!/bin/bash

# Large-Scale Network Performance Test with Geo-Raft Implementation
echo "🚀 LARGE-SCALE GEO-RAFT PERFORMANCE TEST"
echo "=========================================="

# Configuration
TOTAL_TRANSACTIONS=50000
CONCURRENT_CLIENTS=100
TEST_DURATION=600  # 10 minutes
WARMUP_DURATION=60 # 1 minute

echo "📊 Test Configuration:"
echo "   • Total Transactions: $TOTAL_TRANSACTIONS"
echo "   • Concurrent Clients: $CONCURRENT_CLIENTS"
echo "   • Test Duration: $TEST_DURATION seconds"
echo "   • Geographic Regions: 3 (Americas, Europe, Asia-Pacific)"
echo ""

# Check network status
echo "🔍 Checking network status..."
docker compose ps

# Start monitoring dashboard in background
echo ""
echo "📈 Starting real-time monitoring dashboard..."
node monitoring/dashboard.js &
DASHBOARD_PID=$!

# Wait for dashboard to start
sleep 5

echo ""
echo "🌍 Starting Large-Scale Geo-Raft Performance Test..."
echo "=================================================="

# Run comprehensive Caliper benchmark with high load
npx caliper launch manager \
    --caliper-workspace ./caliper \
    --caliper-networkconfig ./caliper/network-config.yaml \
    --caliper-benchconfig ./caliper/large-scale-benchmark.yaml \
    --caliper-flow-only-test \
    --caliper-report-path ./reports

echo ""
echo "📊 Test completed! Generating comprehensive report..."

# Generate detailed performance analysis
node scripts/generate-large-scale-report.js

echo ""
echo "🎯 Performance Test Results:"
echo "============================"
echo "📱 Real-time Dashboard: http://localhost:8080"
echo "📊 Grafana Monitoring: http://localhost:3000"
echo "📈 Prometheus Metrics: http://localhost:9090"
echo "📄 Full Report: ./reports/performance-report.html"

# Keep dashboard running
echo ""
echo "✅ Large-scale performance test completed!"
echo "Dashboard will continue running for real-time monitoring..."
