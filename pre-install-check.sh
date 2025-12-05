#!/bin/bash

################################################################################
# ETH Graffiti Explorer - Pre-Installation Checker
# 
# Run this script BEFORE installation to verify your system is ready
# and won't interfere with DAppNode
################################################################################

# Don't exit on errors - we want to collect all checks
set +e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[?]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo_error() {
    echo -e "${RED}[?]${NC} $1"
}

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

echo ""
echo "======================================================================"
echo "   ETH Graffiti Explorer - Pre-Installation System Check"
echo "======================================================================"
echo ""

################################################################################
# Check 1: Running as Root
################################################################################
echo_info "Check 1: Checking user permissions..."
if [ "$EUID" -eq 0 ]; then
    echo_success "Running as root"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo_error "Not running as root. Please run with sudo"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

################################################################################
# Check 2: Docker Installation
################################################################################
echo_info "Check 2: Checking Docker installation..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo_success "Docker installed: $DOCKER_VERSION"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    
    # Check Docker is running
    if docker ps &> /dev/null; then
        echo_success "Docker daemon is running"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        echo_error "Docker is installed but not running"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
else
    echo_error "Docker is not installed"
    echo_info "DAppNode should have Docker installed. Check your installation."
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

################################################################################
# Check 3: Docker Compose
################################################################################
echo_info "Check 3: Checking Docker Compose..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo_success "Docker Compose available: $COMPOSE_VERSION"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo_error "Docker Compose plugin not found"
    echo_info "Install with: apt-get install docker-compose-plugin"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

################################################################################
# Check 4: DAppNode Detection
################################################################################
echo_info "Check 4: Detecting DAppNode installation..."
DAPPNODE_FOUND=false

if docker ps --format '{{.Names}}' | grep -qi "dappnode"; then
    echo_success "DAppNode containers detected"
    DAPPNODE_FOUND=true
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    
    echo_info "DAppNode containers:"
    docker ps --filter "name=dappnode" --format "  - {{.Names}} ({{.Status}})"
else
    echo_warning "No DAppNode containers found"
    echo_info "This is OK if you're using a custom setup"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
fi

################################################################################
# Check 5: Lodestar Detection
################################################################################
echo_info "Check 5: Detecting Lodestar consensus client..."
if docker ps --format '{{.Names}}' | grep -qi "lodestar"; then
    LODESTAR_CONTAINER=$(docker ps --filter "name=lodestar" --format "{{.Names}}" | head -1)
    echo_success "Lodestar container found: $LODESTAR_CONTAINER"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    
    # Try to find Lodestar IP
    if docker network inspect dncore_network &> /dev/null; then
        LODESTAR_IP=$(docker network inspect dncore_network | grep -A 5 "$LODESTAR_CONTAINER" | grep "IPv4Address" | cut -d'"' -f4 | cut -d'/' -f1)
        if [ ! -z "$LODESTAR_IP" ]; then
            echo_success "Lodestar IP address: $LODESTAR_IP"
            echo_info "Suggested RPC URL: http://$LODESTAR_IP:9596"
        fi
    fi
else
    echo_warning "Lodestar container not found"
    echo_info "Make sure your consensus client is running"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
fi

################################################################################
# Check 6: Available Disk Space
################################################################################
echo_info "Check 6: Checking available disk space..."
AVAILABLE_GB=$(df /var/lib --output=avail -B G | tail -n 1 | tr -dc '0-9')

if [ "$AVAILABLE_GB" -ge 50 ]; then
    echo_success "Sufficient disk space: ${AVAILABLE_GB}GB available"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
elif [ "$AVAILABLE_GB" -ge 20 ]; then
    echo_warning "Low disk space: ${AVAILABLE_GB}GB available (50GB+ recommended)"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
else
    echo_error "Insufficient disk space: ${AVAILABLE_GB}GB available (need at least 20GB)"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

################################################################################
# Check 7: Available RAM
################################################################################
echo_info "Check 7: Checking available RAM..."
AVAILABLE_RAM=$(free -g | awk '/^Mem:/{print $7}')
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')

if [ "$AVAILABLE_RAM" -ge 4 ]; then
    echo_success "Sufficient RAM: ${AVAILABLE_RAM}GB free of ${TOTAL_RAM}GB total"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
elif [ "$AVAILABLE_RAM" -ge 2 ]; then
    echo_warning "Low available RAM: ${AVAILABLE_RAM}GB free (4GB+ recommended)"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
else
    echo_error "Insufficient RAM: ${AVAILABLE_RAM}GB free (need at least 2GB)"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

################################################################################
# Check 8: Port Availability
################################################################################
echo_info "Check 8: Checking required ports..."

check_port() {
    local port=$1
    local service=$2
    
    if ! ss -tuln | grep -q ":$port "; then
        echo_success "Port $port available ($service)"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        echo_warning "Port $port already in use ($service)"
        echo_info "This may be OK if another service is using it"
        CHECKS_WARNING=$((CHECKS_WARNING + 1))
    fi
}

check_port 80 "HTTP"
check_port 443 "HTTPS"

# Check if MongoDB and SQL Server ports are available (localhost only)
if ! ss -tuln | grep -q "127.0.0.1:27017"; then
    echo_success "MongoDB port 27017 available (localhost)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo_warning "Port 27017 in use - MongoDB may already be running"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
fi

if ! ss -tuln | grep -q "127.0.0.1:1433"; then
    echo_success "SQL Server port 1433 available (localhost)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo_warning "Port 1433 in use - SQL Server may already be running"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
fi

################################################################################
# Check 9: System Requirements
################################################################################
echo_info "Check 9: Checking system requirements..."

# Check kernel version
KERNEL_VERSION=$(uname -r)
echo_success "Kernel version: $KERNEL_VERSION"
CHECKS_PASSED=$((CHECKS_PASSED + 1))

# Check if we're on Debian
if [ -f /etc/debian_version ]; then
    DEBIAN_VERSION=$(cat /etc/debian_version)
    echo_success "Debian version: $DEBIAN_VERSION"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo_warning "Not running Debian (detected: $(lsb_release -d | cut -f2))"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
fi

################################################################################
# Check 10: Network Connectivity
################################################################################
echo_info "Check 10: Checking network connectivity..."

if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo_success "Internet connectivity OK"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo_warning "Cannot reach internet (required for Docker image downloads)"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
fi

################################################################################
# Check 11: Docker Networks
################################################################################
echo_info "Check 11: Checking Docker networks..."

if docker network ls | grep -q "dncore_network"; then
    echo_success "DAppNode network 'dncore_network' found"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    echo_warning "DAppNode network 'dncore_network' not found"
    echo_info "Will use alternative network configuration"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
fi

################################################################################
# Check 12: Existing Installation
################################################################################
echo_info "Check 12: Checking for existing installation..."

if [ -d "/opt/eth-graffiti-explorer" ]; then
    echo_warning "Installation directory already exists: /opt/eth-graffiti-explorer"
    echo_info "Previous installation detected. You may want to back it up first."
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
else
    echo_success "No existing installation found"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

if docker ps -a | grep -q "eth-graffiti"; then
    echo_warning "ETH Graffiti Explorer containers already exist"
    echo_info "Run 'docker ps -a | grep eth-graffiti' to see them"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
else
    echo_success "No existing containers found"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

################################################################################
# Summary
################################################################################
echo ""
echo "======================================================================"
echo "   System Check Summary"
echo "======================================================================"
echo ""
echo_success "$CHECKS_PASSED checks passed"
if [ $CHECKS_WARNING -gt 0 ]; then
    echo_warning "$CHECKS_WARNING warnings"
fi
if [ $CHECKS_FAILED -gt 0 ]; then
    echo_error "$CHECKS_FAILED checks failed"
fi
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo_success "System is ready for installation!"
    echo ""
    echo_info "Next steps:"
    echo "  1. Make sure you have a domain name (or use DuckDNS)"
    echo "  2. Find your Lodestar RPC URL (check above)"
    echo "  3. Run the installation script: sudo ./install-debian.sh"
    echo ""
    exit 0
else
    echo_error "Please fix the failed checks before proceeding with installation"
    echo ""
    exit 1
fi

