#!/bin/bash

# Grafana Dashboard Setup Script
# This script helps set up the geo-aware dashboards in Grafana

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Setting up Geo-Aware Fabric Dashboards...${NC}"

# Wait for Grafana to be ready
echo -e "${YELLOW}⏳ Waiting for Grafana to be ready...${NC}"
sleep 10

# Check if Grafana is responding
GRAFANA_URL="http://localhost:3000"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -f "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Grafana is ready!${NC}"
        break
    else
        echo -e "${YELLOW}⏳ Grafana not ready yet, waiting... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)${NC}"
        sleep 5
        RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Grafana failed to start within expected time${NC}"
    exit 1
fi

echo -e "${BLUE}📊 Access Information:${NC}"
echo -e "${GREEN}Grafana Dashboard: http://localhost:3000${NC}"
echo -e "${GREEN}Username: admin${NC}"
echo -e "${GREEN}Password: admin${NC}"
echo ""
echo -e "${BLUE}📈 Available Features:${NC}"
echo -e "• Service Status Monitoring"
echo -e "• Active Services Count"
echo -e "• Geographic Service Distribution"
echo ""
echo -e "${YELLOW}📝 Note: After logging in, go to 'Dashboards' → 'Browse' to see the geo-aware dashboards${NC}"
echo -e "${YELLOW}If dashboards are not visible, they will auto-refresh in a few moments${NC}"

echo -e "${GREEN}🎉 Setup complete! You can now access the Grafana dashboards${NC}"
