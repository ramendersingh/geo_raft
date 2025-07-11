#!/bin/bash

# Enhanced dashboard control script with authentication and service integration
set -e

DASHBOARD_PID_FILE="/tmp/unified-dashboard.pid"
DASHBOARD_PORT=8080
MONITORING_SERVICE_PORT=3000
PROMETHEUS_PORT=9090

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Get process using port
get_port_process() {
    local port=$1
    lsof -Pi :$port -sTCP:LISTEN -t 2>/dev/null || echo ""
}

# Kill process on port
kill_port_process() {
    local port=$1
    local pid=$(get_port_process $port)
    if [ ! -z "$pid" ]; then
        log "Killing process $pid on port $port"
        kill -9 $pid 2>/dev/null || true
        sleep 2
    fi
}

# Check service dependencies
check_dependencies() {
    log "Checking service dependencies..."
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed. Please install Node.js first."
        exit 1
    fi
    
    # Check if required npm packages are installed
    if [ ! -d "node_modules" ]; then
        warning "Node modules not found. Installing dependencies..."
        npm install
    fi
    
    # Check if monitoring service is available
    if check_port $MONITORING_SERVICE_PORT; then
        success "Monitoring service detected on port $MONITORING_SERVICE_PORT"
    else
        warning "Monitoring service not detected on port $MONITORING_SERVICE_PORT"
        warning "Dashboard will run without monitoring service integration"
    fi
    
    # Check if Prometheus is available
    if check_port $PROMETHEUS_PORT; then
        success "Prometheus detected on port $PROMETHEUS_PORT"
    else
        warning "Prometheus not detected on port $PROMETHEUS_PORT"
        warning "Dashboard will run without Prometheus integration"
    fi
}

# Start the unified dashboard
start_dashboard() {
    log "Starting unified dashboard with authentication..."
    
    # Check dependencies first
    check_dependencies
    
    # Check if dashboard is already running
    if [ -f "$DASHBOARD_PID_FILE" ]; then
        local existing_pid=$(cat "$DASHBOARD_PID_FILE")
        if ps -p $existing_pid > /dev/null 2>&1; then
            warning "Dashboard is already running (PID: $existing_pid)"
            return 0
        else
            rm -f "$DASHBOARD_PID_FILE"
        fi
    fi
    
    # Kill any process using the dashboard port
    if check_port $DASHBOARD_PORT; then
        warning "Port $DASHBOARD_PORT is in use. Cleaning up..."
        kill_port_process $DASHBOARD_PORT
    fi
    
    # Set environment variables
    export NODE_ENV=production
    export PORT=$DASHBOARD_PORT
    export MONITORING_SERVICE_URL="http://localhost:$MONITORING_SERVICE_PORT"
    export PROMETHEUS_URL="http://localhost:$PROMETHEUS_PORT"
    export SESSION_SECRET=$(openssl rand -hex 32)
    
    # Start the dashboard
    cd monitoring
    nohup node unified-dashboard.js > ../logs/unified-dashboard.log 2>&1 &
    local dashboard_pid=$!
    echo $dashboard_pid > "$DASHBOARD_PID_FILE"
    
    # Wait a moment for startup
    sleep 3
    
    # Verify the dashboard started successfully
    if ps -p $dashboard_pid > /dev/null 2>&1; then
        success "✅ Unified dashboard started successfully!"
        success "🌐 Dashboard URL: http://localhost:$DASHBOARD_PORT"
        success "🔐 Default credentials: admin/admin123"
        success "📊 Features:"
        echo "   • Real-time performance monitoring"
        echo "   • Caliper benchmark integration"
        echo "   • Historical data tracking"
        echo "   • Regional performance analysis"
        echo "   • Prometheus metrics integration"
        echo "   • Monitoring service integration"
        echo "   • Secure authentication"
        log "Dashboard PID: $dashboard_pid"
        
        # Show service integration status
        echo ""
        log "Service Integration Status:"
        if check_port $MONITORING_SERVICE_PORT; then
            success "✅ Monitoring Service (Port $MONITORING_SERVICE_PORT): Connected"
        else
            warning "⚠️  Monitoring Service (Port $MONITORING_SERVICE_PORT): Not Available"
        fi
        
        if check_port $PROMETHEUS_PORT; then
            success "✅ Prometheus (Port $PROMETHEUS_PORT): Connected"
        else
            warning "⚠️  Prometheus (Port $PROMETHEUS_PORT): Not Available"
        fi
        
    else
        error "❌ Failed to start unified dashboard"
        rm -f "$DASHBOARD_PID_FILE"
        return 1
    fi
}

# Stop the unified dashboard
stop_dashboard() {
    log "Stopping unified dashboard..."
    
    local stopped=false
    
    # Stop using PID file
    if [ -f "$DASHBOARD_PID_FILE" ]; then
        local pid=$(cat "$DASHBOARD_PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            log "Stopping dashboard process (PID: $pid)"
            kill -TERM $pid 2>/dev/null || true
            
            # Wait for graceful shutdown
            local count=0
            while ps -p $pid > /dev/null 2>&1 && [ $count -lt 10 ]; do
                sleep 1
                ((count++))
            done
            
            # Force kill if still running
            if ps -p $pid > /dev/null 2>&1; then
                warning "Forcing dashboard shutdown..."
                kill -9 $pid 2>/dev/null || true
            fi
            stopped=true
        fi
        rm -f "$DASHBOARD_PID_FILE"
    fi
    
    # Also kill any process on the dashboard port
    if check_port $DASHBOARD_PORT; then
        warning "Cleaning up port $DASHBOARD_PORT"
        kill_port_process $DASHBOARD_PORT
        stopped=true
    fi
    
    if [ "$stopped" = true ]; then
        success "✅ Unified dashboard stopped successfully"
    else
        warning "⚠️  Dashboard was not running"
    fi
}

# Restart the dashboard
restart_dashboard() {
    log "Restarting unified dashboard..."
    stop_dashboard
    sleep 2
    start_dashboard
}

# Show dashboard status
show_status() {
    log "Unified Dashboard Status:"
    echo ""
    
    # Check dashboard status
    if [ -f "$DASHBOARD_PID_FILE" ]; then
        local pid=$(cat "$DASHBOARD_PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            success "✅ Dashboard: Running (PID: $pid)"
            echo "   📍 URL: http://localhost:$DASHBOARD_PORT"
            echo "   🔐 Authentication: Enabled"
        else
            error "❌ Dashboard: Not Running (stale PID file)"
            rm -f "$DASHBOARD_PID_FILE"
        fi
    else
        if check_port $DASHBOARD_PORT; then
            warning "⚠️  Dashboard: Running (unknown PID) on port $DASHBOARD_PORT"
        else
            error "❌ Dashboard: Not Running"
        fi
    fi
    
    echo ""
    log "Service Integration Status:"
    
    # Check monitoring service
    if check_port $MONITORING_SERVICE_PORT; then
        success "✅ Monitoring Service: Available on port $MONITORING_SERVICE_PORT"
    else
        error "❌ Monitoring Service: Not available on port $MONITORING_SERVICE_PORT"
    fi
    
    # Check Prometheus
    if check_port $PROMETHEUS_PORT; then
        success "✅ Prometheus: Available on port $PROMETHEUS_PORT"
    else
        error "❌ Prometheus: Not available on port $PROMETHEUS_PORT"
    fi
    
    # Check Docker Compose
    if command -v docker &> /dev/null && docker compose ps &> /dev/null; then
        local running_containers=$(docker compose ps --filter "status=running" --format "table {{.Service}}" | tail -n +2 | wc -l)
        success "✅ Docker Compose: $running_containers containers running"
    else
        warning "⚠️  Docker Compose: Not available or no containers running"
    fi
}

# Open dashboard in browser
open_dashboard() {
    if check_port $DASHBOARD_PORT; then
        log "Opening dashboard in browser..."
        
        # Try different browsers
        if command -v xdg-open &> /dev/null; then
            xdg-open "http://localhost:$DASHBOARD_PORT" &
        elif command -v open &> /dev/null; then
            open "http://localhost:$DASHBOARD_PORT" &
        elif command -v start &> /dev/null; then
            start "http://localhost:$DASHBOARD_PORT" &
        else
            log "Please open http://localhost:$DASHBOARD_PORT in your browser"
        fi
        
        success "🌐 Dashboard URL: http://localhost:$DASHBOARD_PORT"
        success "🔐 Default credentials: admin/admin123"
    else
        error "❌ Dashboard is not running. Please start it first."
        return 1
    fi
}

# Clean up resources
clean_dashboard() {
    log "Cleaning up dashboard resources..."
    
    stop_dashboard
    
    # Clean up log files
    if [ -f "../logs/unified-dashboard.log" ]; then
        > ../logs/unified-dashboard.log
        log "Cleared dashboard log file"
    fi
    
    # Clean up temporary files
    rm -f "$DASHBOARD_PID_FILE"
    
    success "✅ Dashboard resources cleaned up"
}

# Show help
show_help() {
    echo "Enhanced Unified Dashboard Control Script"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|open|clean|help}"
    echo ""
    echo "Commands:"
    echo "  start    - Start the unified dashboard with authentication"
    echo "  stop     - Stop the unified dashboard"
    echo "  restart  - Restart the unified dashboard"
    echo "  status   - Show dashboard and service status"
    echo "  open     - Open dashboard in browser"
    echo "  clean    - Clean up dashboard resources"
    echo "  help     - Show this help message"
    echo ""
    echo "Features:"
    echo "  • Grafana-style authentication system"
    echo "  • Prometheus metrics integration"
    echo "  • Monitoring service integration (port 3000)"
    echo "  • Real-time performance monitoring"
    echo "  • Historical benchmark tracking"
    echo "  • Regional performance analysis"
    echo ""
    echo "Environment Variables:"
    echo "  PORT                     - Dashboard port (default: 8080)"
    echo "  MONITORING_SERVICE_URL   - Monitoring service URL"
    echo "  PROMETHEUS_URL           - Prometheus server URL"
    echo "  SESSION_SECRET           - Session encryption secret"
    echo "  ADMIN_PASSWORD_HASH      - Admin password hash"
}

# Create logs directory if it doesn't exist
mkdir -p ../logs

# Main command handler
case "${1:-help}" in
    start)
        start_dashboard
        ;;
    stop)
        stop_dashboard
        ;;
    restart)
        restart_dashboard
        ;;
    status)
        show_status
        ;;
    open)
        open_dashboard
        ;;
    clean)
        clean_dashboard
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
