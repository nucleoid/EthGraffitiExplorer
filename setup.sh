#!/bin/bash

################################################################################
# Quick Setup Helper
# Makes all scripts executable and shows next steps
################################################################################

echo "Making scripts executable..."
chmod +x install-debian.sh
chmod +x pre-install-check.sh

echo "? Scripts are now executable"
echo ""
echo "======================================================================"
echo "  ETH Graffiti Explorer - Quick Start for DAppNode"
echo "======================================================================"
echo ""
echo "This installation is SAFE for DAppNode validators."
echo "It will NOT interfere with your validator operation."
echo ""
echo "Step 1: Run pre-installation check"
echo "  sudo ./pre-install-check.sh"
echo ""
echo "Step 2: Review the results and make note of:"
echo "  - Your Lodestar RPC URL (will be shown in the output)"
echo "  - Available disk space and RAM"
echo ""
echo "Step 3: Get a domain name (optional but recommended)"
echo "  Option A: Use DuckDNS (free): https://www.duckdns.org/"
echo "  Option B: Use your own domain"
echo "  Option C: Skip SSL and use IP only (for testing)"
echo ""
echo "Step 4: Run the installation"
echo "  sudo ./install-debian.sh"
echo ""
echo "Step 5: Access your installation"
echo "  Web UI: https://your-domain.com"
echo "  API: https://your-domain.com/api"
echo "  Swagger: https://your-domain.com/swagger"
echo ""
echo "======================================================================"
echo ""
echo "Documentation available:"
echo "  - DAPPNODE_COMPATIBILITY.md - Safety and compatibility info"
echo "  - LODESTAR_RPC_GUIDE.md - Finding your Lodestar RPC URL"
echo "  - DEPLOYMENT_DEBIAN.md - Full deployment guide"
echo "  - SETUP.md - Complete setup instructions"
echo ""
echo "Ready to start? Run: sudo ./pre-install-check.sh"
echo ""
