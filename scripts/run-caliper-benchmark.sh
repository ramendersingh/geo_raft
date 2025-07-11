#!/bin/bash

echo "🏃 RUNNING CALIPER BENCHMARK..."
echo "==============================="

# Ensure we're in the right directory
cd "$(dirname "$0")/.." || exit 1

# Check prerequisites
echo "1️⃣ Checking prerequisites..."
if ! ./scripts/setup-caliper.sh; then
    echo "❌ Caliper setup failed"
    exit 1
fi

# Ensure dashboard is running for metrics collection
echo "2️⃣ Ensuring dashboard is running..."
if ! pgrep -f "unified-dashboard.js" > /dev/null; then
    echo "📊 Starting dashboard for metrics collection..."
    ./scripts/fix-dashboard.sh
    sleep 5
fi

# Navigate to Caliper directory
cd caliper || exit 1

# Create benchmark results directory
mkdir -p ../reports/caliper-results

# Run the benchmark
echo "3️⃣ Starting Caliper benchmark..."
echo "This may take several minutes..."

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="../reports/caliper-results/benchmark_$TIMESTAMP.html"

echo "📊 Running benchmark with geo-aware analysis..."

# Run Caliper with proper configuration
caliper launch manager \
    --caliper-workspace ./ \
    --caliper-networkconfig network-config.yaml \
    --caliper-benchconfig benchmark-config.yaml \
    --caliper-flow-only-test \
    --caliper-report-path "$REPORT_FILE" \
    2>&1 | tee "../logs/caliper_$TIMESTAMP.log"

CALIPER_EXIT_CODE=$?

if [ $CALIPER_EXIT_CODE -eq 0 ]; then
    echo "✅ Benchmark completed successfully!"
    
    # Check if report was generated
    if [ -f "$REPORT_FILE" ]; then
        echo "📈 Report generated: $REPORT_FILE"
    fi
    
    # Extract key metrics
    echo ""
    echo "📊 BENCHMARK RESULTS SUMMARY"
    echo "============================"
    
    # Parse results from log
    LOG_FILE="../logs/caliper_$TIMESTAMP.log"
    if [ -f "$LOG_FILE" ]; then
        echo "📋 Key Metrics:"
        grep -i "tps\|throughput\|latency\|success" "$LOG_FILE" | tail -10
    fi
    
else
    echo "❌ Benchmark failed with exit code: $CALIPER_EXIT_CODE"
    echo "📋 Check logs for details:"
    tail -20 "../logs/caliper_$TIMESTAMP.log"
fi

# Update dashboard with results
echo "4️⃣ Updating dashboard with results..."
if [ -f "$REPORT_FILE" ]; then
    # Notify dashboard of new benchmark results
    curl -s -X POST http://localhost:8080/api/benchmark-complete \
        -H "Content-Type: application/json" \
        -d "{\"reportPath\":\"$REPORT_FILE\",\"timestamp\":\"$TIMESTAMP\"}" || true
fi

echo ""
echo "🎯 CALIPER BENCHMARK COMPLETE"
echo "============================="
echo "Log file: logs/caliper_$TIMESTAMP.log"
echo "Report: $REPORT_FILE"
echo "Dashboard: http://localhost:8080"
echo ""
echo "🔍 To view detailed results:"
echo "   - Open the HTML report in a browser"
echo "   - Check the unified dashboard"
echo "   - Review the log file for detailed metrics"
