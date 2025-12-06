#!/bin/bash

################################################################################
# ETH Graffiti Explorer - Fix Beacon Node URL
# 
# This script helps update the beacon node URL after installation
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ "$EUID" -ne 0 ]; then 
    echo_error "Please run as root (use sudo)"
    exit 1
fi

INSTALL_DIR="/opt/eth-graffiti-explorer"

if [ ! -d "$INSTALL_DIR" ]; then
    echo_error "ETH Graffiti Explorer not found at $INSTALL_DIR"
    exit 1
fi

cd $INSTALL_DIR

echo_info "=== ETH Graffiti Explorer - Beacon Node URL Fix ==="
echo ""

# Detect current beacon URL
CURRENT_URL=$(grep "BEACON_RPC_URL=" .env 2>/dev/null | cut -d'=' -f2 || echo "unknown")
echo_info "Current beacon node URL: $CURRENT_URL"
echo ""

# Auto-detect Lodestar
echo_info "Detecting Lodestar beacon node..."
SUGGESTED_URL=""

# Method 1: Find Lodestar container IP
if docker ps --format '{{.Names}}' | grep -q "lodestar"; then
    LODESTAR_CONTAINER=$(docker ps --format '{{.Names}}' | grep lodestar | head -1)
    echo_info "Found Lodestar container: $LODESTAR_CONTAINER"
    
    LODESTAR_IP=$(docker inspect $LODESTAR_CONTAINER 2>/dev/null | grep -A 10 "dncore_network" | grep "IPv4Address" | cut -d'"' -f4 | cut -d'/' -f1)
    
    if [ ! -z "$LODESTAR_IP" ]; then
        SUGGESTED_URL="http://${LODESTAR_IP}:9596"
        echo_success "Detected Lodestar IP: $LODESTAR_IP"
        
        # Test it
        if docker exec eth-graffiti-api curl -s -m 3 "$SUGGESTED_URL/eth/v1/node/version" &>/dev/null; then
            echo_success "Verified: $SUGGESTED_URL is accessible!"
        else
            echo_info "Cannot verify URL (API container may not be running)"
        fi
    fi
fi

# Method 2: Try common DAppNode URLs
if [ -z "$SUGGESTED_URL" ]; then
    echo_info "Testing common DAppNode URLs..."
    
    if docker exec eth-graffiti-api curl -s -m 2 http://lodestar.dappnode:9596/eth/v1/node/version &>/dev/null 2>&1; then
        SUGGESTED_URL="http://lodestar.dappnode:9596"
        echo_success "Found: $SUGGESTED_URL (DAppNode DNS)"
    elif docker exec eth-graffiti-api curl -s -m 2 http://172.33.1.5:9596/eth/v1/node/version &>/dev/null 2>&1; then
        SUGGESTED_URL="http://172.33.1.5:9596"
        echo_success "Found: $SUGGESTED_URL (Common IP)"
    elif docker exec eth-graffiti-api curl -s -m 2 http://host.docker.internal:9596/eth/v1/node/version &>/dev/null 2>&1; then
        SUGGESTED_URL="http://host.docker.internal:9596"
        echo_success "Found: $SUGGESTED_URL (Host network)"
    else
        SUGGESTED_URL="http://172.33.1.5:9596"
        echo_info "Could not auto-detect, suggesting common default"
    fi
fi

echo ""
echo_info "Suggested URLs (in order of preference):"
echo "  1. $SUGGESTED_URL (auto-detected)"
echo "  2. http://lodestar.dappnode:9596 (DAppNode DNS)"
echo "  3. http://172.33.1.5:9596 (common IP)"
echo "  4. http://host.docker.internal:9596 (host network)"
echo ""

read -p "Enter new beacon node URL [$SUGGESTED_URL]: " NEW_URL
NEW_URL=${NEW_URL:-$SUGGESTED_URL}

echo ""
echo_info "Updating configuration..."

# Update .env file
sed -i "s|BEACON_RPC_URL=.*|BEACON_RPC_URL=$NEW_URL|g" .env

# Update docker-compose.yml
sed -i "s|BeaconNode__Url:.*|BeaconNode__Url: \"$NEW_URL\"|g" docker-compose.yml

echo_success "Configuration updated!"
echo ""

# Restart services
echo_info "Restarting services..."
docker compose down
sleep 2
docker compose up -d

echo ""
echo_success "Services restarted!"
echo ""

# Wait for API to be ready
echo_info "Waiting for API to start (15 seconds)..."
sleep 15

# Test the connection
echo_info "Testing beacon node connection..."
if docker exec eth-graffiti-api curl -s -m 5 "$NEW_URL/eth/v1/node/version" &>/dev/null; then
    echo_success "? SUCCESS! Beacon node is accessible at: $NEW_URL"
    
    # Get version info
    VERSION=$(docker exec eth-graffiti-api curl -s "$NEW_URL/eth/v1/node/version" 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    if [ ! -z "$VERSION" ]; then
        echo_success "? Beacon node version: $VERSION"
    fi
else
    echo_error "? Cannot reach beacon node at: $NEW_URL"
    echo ""
    echo_info "Troubleshooting steps:"
    echo "  1. Verify Lodestar is running: docker ps | grep lodestar"
    echo "  2. Check Lodestar logs: docker logs <lodestar-container>"
    echo "  3. Verify API container network: docker network inspect dncore_network | grep eth-graffiti-api"
    echo "  4. Try running this script again with a different URL"
    echo ""
    echo_info "Common URLs to try:"
    echo "  - http://lodestar.dappnode:9596"
    echo "  - http://172.33.1.5:9596"
    echo "  - http://172.33.1.6:9596"
    echo "  - http://host.docker.internal:9596"
fi

echo ""
echo_info "Current configuration:"
echo "  Beacon URL: $NEW_URL"
echo "  Status: ./status.sh"
echo "  Logs: ./logs.sh api"
echo ""
