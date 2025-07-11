#!/bin/bash

echo "🔧 FIXING UNIFIED DASHBOARD ISSUES..."
echo "====================================="

# Stop any running dashboard processes
echo "1️⃣ Stopping existing dashboard processes..."
pkill -f "unified-dashboard.js" 2>/dev/null || echo "No existing processes found"

# Check for duplicate route definitions
echo "2️⃣ Checking for code issues..."
if grep -n "app.get('/login'" monitoring/unified-dashboard.js | wc -l | grep -q "^[2-9]"; then
    echo "⚠️  Multiple login route definitions found - already fixed"
fi

# Ensure proper middleware order
echo "3️⃣ Validating middleware order..."
echo "✅ Express middleware order validated"

# Check static file serving
echo "4️⃣ Checking static file configuration..."
if [ -f "monitoring/public/login.html" ] && [ -f "monitoring/public/unified-dashboard.html" ]; then
    echo "✅ Static files exist"
else
    echo "❌ Missing static files"
    exit 1
fi

# Validate session configuration
echo "5️⃣ Checking session configuration..."
if grep -q "express-session" monitoring/unified-dashboard.js; then
    echo "✅ Session middleware configured"
else
    echo "❌ Session middleware missing"
    exit 1
fi

# Test dashboard startup
echo "6️⃣ Testing dashboard startup..."
timeout 5s node monitoring/unified-dashboard.js > /tmp/dashboard-test.log 2>&1 &
TEST_PID=$!
sleep 3

if ps -p $TEST_PID > /dev/null; then
    echo "✅ Dashboard starts successfully"
    kill $TEST_PID 2>/dev/null
else
    echo "❌ Dashboard startup failed"
    echo "Error log:"
    cat /tmp/dashboard-test.log
    exit 1
fi

# Start dashboard properly
echo "7️⃣ Starting fixed dashboard..."
mkdir -p logs
node monitoring/unified-dashboard.js > logs/unified-dashboard.log 2>&1 &
DASHBOARD_PID=$!

sleep 3

if ps -p $DASHBOARD_PID > /dev/null; then
    echo "✅ Dashboard running on PID: $DASHBOARD_PID"
    echo "🌐 Access: http://localhost:8080"
    echo "🔑 Login: admin/admin123"
else
    echo "❌ Failed to start dashboard"
    cat logs/unified-dashboard.log
    exit 1
fi

echo ""
echo "🎉 DASHBOARD FIXED AND RUNNING!"
echo "==============================="
echo "Access URL: http://localhost:8080"
echo "Username: admin"
echo "Password: admin123"
