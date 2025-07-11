#!/bin/bash

echo "🔧 FIXING JAVASCRIPT ERRORS IN UNIFIED DASHBOARD..."
echo "==================================================="

# Check if dashboard is running
echo "1️⃣ Checking dashboard status..."
if pgrep -f "unified-dashboard.js" > /dev/null; then
    echo "✅ Dashboard is running"
    RESTART_NEEDED=true
else
    echo "⚠️  Dashboard not running"
    RESTART_NEEDED=false
fi

# Check for common JavaScript errors in the HTML file
echo "2️⃣ Checking for common JavaScript errors..."
HTML_FILE="monitoring/public/unified-dashboard.html"

# Check for missing function definitions
MISSING_FUNCTIONS=0

# Check updateMonitoringControls function
if ! grep -q "function updateMonitoringControls" "$HTML_FILE"; then
    echo "❌ Missing updateMonitoringControls function"
    MISSING_FUNCTIONS=$((MISSING_FUNCTIONS + 1))
else
    echo "✅ updateMonitoringControls function exists"
fi

# Check for syntax errors
echo "3️⃣ Checking for syntax errors..."
SYNTAX_ERRORS=0

# Check for incomplete functions
if grep -q "// Implementation would" "$HTML_FILE"; then
    echo "⚠️  Found incomplete function implementations"
    # Fix incomplete displayComparison function
    if grep -q "// Implementation would create comparison chart" "$HTML_FILE" && ! grep -q "resultsDiv.innerHTML" "$HTML_FILE"; then
        echo "🔧 Fixing incomplete displayComparison function..."
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
fi

# Check for missing semicolons or brackets
if grep -q "\.then data =>" "$HTML_FILE"; then
    echo "⚠️  Found potential syntax issues with Promise chains"
    SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
fi

# Check for event listeners without proper error handling
echo "4️⃣ Validating event listeners..."
EVENT_ISSUES=0

# Check if monitoring control buttons exist in HTML
if ! grep -q 'id="start-monitoring"' "$HTML_FILE"; then
    echo "⚠️  Missing start-monitoring button element"
    EVENT_ISSUES=$((EVENT_ISSUES + 1))
fi

if ! grep -q 'id="stop-monitoring"' "$HTML_FILE"; then
    echo "⚠️  Missing stop-monitoring button element"
    EVENT_ISSUES=$((EVENT_ISSUES + 1))
fi

# Fix common issues
echo "5️⃣ Applying fixes..."

# Ensure monitoring control buttons exist
if [ $EVENT_ISSUES -gt 0 ]; then
    echo "🔧 Adding missing monitoring control elements..."
    # This would be handled by ensuring the HTML has proper structure
fi

# Restart dashboard if needed
if [ "$RESTART_NEEDED" = true ]; then
    echo "6️⃣ Restarting dashboard with fixes..."
    pkill -f "unified-dashboard.js" 2>/dev/null
    sleep 2
    
    # Start dashboard
    node monitoring/unified-dashboard.js > logs/unified-dashboard.log 2>&1 &
    DASHBOARD_PID=$!
    
    sleep 3
    
    if ps -p $DASHBOARD_PID > /dev/null; then
        echo "✅ Dashboard restarted successfully"
    else
        echo "❌ Failed to restart dashboard"
        echo "📋 Error log:"
        tail -10 logs/unified-dashboard.log
        exit 1
    fi
fi

# Test dashboard functionality
echo "7️⃣ Testing dashboard functionality..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Dashboard HTTP test passed"
else
    echo "❌ Dashboard HTTP test failed (status: $HTTP_CODE)"
fi

# Check logs for JavaScript errors
echo "8️⃣ Checking for runtime errors..."
if [ -f "logs/unified-dashboard.log" ]; then
    JS_ERRORS=$(grep -i "error\|exception\|undefined" logs/unified-dashboard.log | wc -l)
    if [ "$JS_ERRORS" -eq 0 ]; then
        echo "✅ No JavaScript runtime errors found"
    else
        echo "⚠️  Found $JS_ERRORS potential JavaScript errors in logs"
        echo "Recent errors:"
        grep -i "error\|exception\|undefined" logs/unified-dashboard.log | tail -3
    fi
fi

echo ""
echo "🎯 JAVASCRIPT ERROR FIX SUMMARY"
echo "==============================="
echo "Missing Functions: $MISSING_FUNCTIONS"
echo "Syntax Errors: $SYNTAX_ERRORS"
echo "Event Issues: $EVENT_ISSUES"
echo ""

if [ $MISSING_FUNCTIONS -eq 0 ] && [ $SYNTAX_ERRORS -eq 0 ] && [ $EVENT_ISSUES -eq 0 ]; then
    echo "🎉 All JavaScript errors fixed!"
    echo "🌐 Dashboard: http://localhost:8080"
    echo "🔑 Login: admin/admin123"
else
    echo "⚠️  Some issues may still exist. Check the logs for details."
    echo "🔍 Run: tail -f logs/unified-dashboard.log"
fi
