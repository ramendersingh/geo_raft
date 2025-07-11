#!/bin/bash

echo "🧪 TESTING UNIFIED DASHBOARD..."
echo "==============================="

# Test if dashboard is running
echo "1️⃣ Checking if dashboard is running..."
if ! pgrep -f "unified-dashboard.js" > /dev/null; then
    echo "❌ Dashboard not running. Starting it..."
    ./scripts/fix-dashboard.sh
    sleep 5
fi

# Test HTTP access
echo "2️⃣ Testing HTTP access..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Dashboard HTTP accessible (status: $HTTP_CODE)"
else
    echo "❌ Dashboard HTTP not accessible (status: $HTTP_CODE)"
    exit 1
fi

# Test login page
echo "3️⃣ Testing login page access..."
LOGIN_TEST=$(curl -s http://localhost:8080/login | grep -o "<title.*title>" | head -1)
if [[ "$LOGIN_TEST" == *"Login"* ]]; then
    echo "✅ Login page accessible"
else
    echo "❌ Login page not accessible"
    exit 1
fi

# Test authentication
echo "4️⃣ Testing authentication API..."
AUTH_TEST=$(curl -s -X POST http://localhost:8080/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' | grep -o "success")

if [ "$AUTH_TEST" = "success" ]; then
    echo "✅ Authentication working"
else
    echo "❌ Authentication failed"
    echo "Testing with debug..."
    curl -s -X POST http://localhost:8080/login \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}'
fi

# Test dashboard page (after auth)
echo "5️⃣ Testing dashboard page..."
DASHBOARD_HTML=$(curl -s http://localhost:8080/dashboard | head -1)
if [[ "$DASHBOARD_HTML" == *"html"* ]] || [[ "$DASHBOARD_HTML" == *"302"* ]]; then
    echo "✅ Dashboard page accessible"
else
    echo "⚠️  Dashboard requires authentication (expected)"
fi

# Test API endpoints
echo "6️⃣ Testing API endpoints..."
API_STATUS=$(curl -s http://localhost:8080/api/status | grep -o "error")
if [ "$API_STATUS" = "error" ]; then
    echo "✅ API properly requires authentication"
else
    echo "⚠️  API endpoint response unclear"
fi

# Check logs for errors
echo "7️⃣ Checking for errors in logs..."
if [ -f "logs/unified-dashboard.log" ]; then
    ERROR_COUNT=$(grep -i "error" logs/unified-dashboard.log | wc -l)
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo "✅ No errors in dashboard logs"
    else
        echo "⚠️  Found $ERROR_COUNT errors in logs:"
        grep -i "error" logs/unified-dashboard.log | tail -3
    fi
else
    echo "⚠️  No log file found"
fi

echo ""
echo "🎯 DASHBOARD TEST SUMMARY"
echo "========================"
echo "Dashboard Status: $(pgrep -f "unified-dashboard.js" > /dev/null && echo "✅ Running" || echo "❌ Not Running")"
echo "HTTP Access: $([ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ] && echo "✅ Working" || echo "❌ Failed")"
echo "Authentication: $([ "$AUTH_TEST" = "success" ] && echo "✅ Working" || echo "❌ Failed")"
echo ""
echo "🌐 Access URL: http://localhost:8080"
echo "🔑 Credentials: admin/admin123"
echo ""
echo "🔍 To view logs: tail -f logs/unified-dashboard.log"
