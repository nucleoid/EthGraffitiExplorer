#!/bin/bash

################################################################################
# ETH Graffiti Explorer - Diagnostic Script
# Helps diagnose connectivity issues between containers
################################################################################

echo "=========================================="
echo "ETH Graffiti Explorer - Diagnostics"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1. Container Status${NC}"
echo "-------------------------------------------"
docker ps --filter "name=eth-graffiti" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo -e "${BLUE}2. Network Connectivity${NC}"
echo "-------------------------------------------"
echo -n "Web -> API connection: "
if docker exec eth-graffiti-web curl -s -f -m 5 http://api:80/health > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${RED}? FAILED${NC}"
    echo "  Web container cannot reach API container"
fi

echo -n "API health check: "
if docker exec eth-graffiti-api curl -s -f -m 5 http://localhost:80/health > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${RED}? FAILED${NC}"
    echo "  API is not responding to health checks"
fi

echo -n "API -> MongoDB connection: "
if docker exec eth-graffiti-api curl -s -f -m 5 http://localhost:80/health > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${YELLOW}? UNKNOWN${NC}"
fi

echo -n "API -> SQL Server connection: "
if docker exec eth-graffiti-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -Q "SELECT 1" -C 2>&1 | grep -q "1 rows affected"; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${RED}? FAILED${NC}"
fi

echo ""

echo -e "${BLUE}3. API Endpoints${NC}"
echo "-------------------------------------------"
echo "Testing API endpoints from host:"

echo -n "  /health: "
if curl -s -f -m 5 http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${RED}? FAILED${NC}"
fi

echo -n "  /api/graffiti/recent: "
RESPONSE=$(curl -s -w "%{http_code}" -m 5 http://localhost:8080/api/graffiti/recent?count=1 -o /dev/null)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}? OK (HTTP $RESPONSE)${NC}"
elif [ "$RESPONSE" = "404" ]; then
    echo -e "${YELLOW}! Not Found (HTTP $RESPONSE)${NC}"
else
    echo -e "${RED}? FAILED (HTTP $RESPONSE)${NC}"
fi

echo -n "  /swagger: "
if curl -s -f -m 5 http://localhost:8080/swagger/index.html > /dev/null 2>&1; then
    echo -e "${GREEN}? OK${NC}"
else
    echo -e "${YELLOW}! May not be available${NC}"
fi

echo ""

echo -e "${BLUE}4. Environment Variables${NC}"
echo "-------------------------------------------"
echo "API container environment:"
docker exec eth-graffiti-api printenv | grep -E "(ASPNETCORE|ConnectionStrings|MongoDB|BeaconNode)" | head -5
echo ""
echo "Web container environment:"
docker exec eth-graffiti-web printenv | grep -E "(ASPNETCORE|ApiSettings)" | head -3
echo ""

echo -e "${BLUE}5. Recent Logs (Last 20 lines)${NC}"
echo "-------------------------------------------"
echo "API logs:"
docker logs eth-graffiti-api --tail=20 2>&1 | tail -10
echo ""
echo "Web logs:"
docker logs eth-graffiti-web --tail=20 2>&1 | tail -10
echo ""

echo -e "${BLUE}6. Database Status${NC}"
echo "-------------------------------------------"
echo -n "MongoDB: "
if docker exec eth-graffiti-mongodb mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}? Running${NC}"
    echo -n "  Graffiti count: "
    COUNT=$(docker exec eth-graffiti-mongodb mongosh EthGraffitiExplorer --quiet --eval "db.graffiti.countDocuments()" 2>/dev/null | tail -1)
    echo "$COUNT documents"
else
    echo -e "${RED}? Not responding${NC}"
fi

echo -n "SQL Server: "
if docker exec eth-graffiti-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -Q "SELECT 1" -C 2>&1 | grep -q "1 rows affected"; then
    echo -e "${GREEN}? Running${NC}"
else
    echo -e "${RED}? Not responding${NC}"
fi

echo ""
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "Common Issues:"
echo "  1. API not responding -> Check logs: docker logs eth-graffiti-api"
echo "  2. Web can't reach API -> Check network: docker network inspect eth-graffiti-net"
echo "  3. Database connection -> Check passwords in .env file"
echo "  4. No data -> Run sync: curl -X POST http://localhost:8080/api/beacon/sync"
echo ""
