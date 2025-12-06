#!/bin/bash

################################################################################
# Quick Port Test Script
# Tests connectivity to ETH Graffiti Explorer on alternate ports
################################################################################

echo "=========================================="
echo "ETH Graffiti Explorer - Port Test"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test HTTP port
echo -n "Testing HTTP (port 8080)... "
if curl -s -f -m 5 http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${RED}? FAILED${NC}"
    echo "  Try: sudo docker ps | grep nginx"
fi

# Test HTTPS port
echo -n "Testing HTTPS (port 8443)... "
if curl -s -k -f -m 5 https://localhost:8443/health > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${YELLOW}? NOT CONFIGURED (SSL may not be enabled)${NC}"
fi

# Test API
echo -n "Testing API... "
if curl -s -f -m 5 http://localhost:8080/api/graffiti/recent?count=1 > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${RED}? FAILED${NC}"
    echo "  API may still be starting up"
fi

# Check if containers are running
echo ""
echo "Container Status:"
docker ps --filter "name=eth-graffiti" --format "  {{.Names}}: {{.Status}}"

echo ""
echo "=========================================="
echo "Access URLs:"
echo "  Web UI:  http://localhost:8080"
echo "  API:     http://localhost:8080/api"
echo "  Swagger: http://localhost:8080/swagger"
echo "=========================================="
