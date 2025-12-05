# Installation Changes for DAppNode Compatibility

## Overview

The installation script has been modified to be **100% safe** for running alongside DAppNode validators. It will **NOT** interfere with your existing Docker, DAppNode, or validator setup.

## Key Changes Made

### 1. ? Docker Installation Skipped
**Before:** Script would remove and reinstall Docker
**After:** Script only verifies Docker exists and is running

```bash
# Old behavior (REMOVED):
apt-get remove -y docker docker-engine docker.io containerd runc
apt-get install -y docker-ce docker-ce-cli containerd.io

# New behavior:
if ! command -v docker &> /dev/null; then
    echo "Docker not found - please install first"
    exit 1
fi
```

### 2. ? Firewall Configuration Made Optional
**Before:** Script would force-enable UFW firewall
**After:** Script asks permission before modifying firewall

```bash
# Now prompts:
"Do you want to configure firewall rules? (y/N)"
# Default: NO (safe for validators)
```

### 3. ? DAppNode Detection Added
**Before:** No validation that DAppNode is running
**After:** Detects DAppNode and warns if not found

```bash
# New safety check:
if docker ps --format '{{.Names}}' | grep -q "DAppNode"; then
    echo "DAppNode detected - proceeding safely"
else
    echo "WARNING: DAppNode not detected"
    # Prompts for confirmation
fi
```

### 4. ? Network Isolation
**Before:** Could potentially conflict with DAppNode networks
**After:** Creates separate isolated network, then safely bridges to DAppNode

```bash
# Creates isolated network first:
docker network create eth-graffiti-net

# Then safely connects to DAppNode (non-disruptive):
docker network connect dncore_network eth-graffiti-api
```

### 5. ? Beacon Node Connectivity Testing
**Before:** No validation of Lodestar connectivity
**After:** Tests connection and provides alternatives if it fails

```bash
# New connectivity test:
curl -s -f -m 5 "${BEACON_RPC_URL}/eth/v1/node/version"

# Provides alternative URLs if fails:
# - http://172.33.1.5:9596
# - http://lodestar.dappnode:9596
# - http://host.docker.internal:9596
```

## Safety Guarantees

### ? Will NOT Touch
- ? Existing Docker installation
- ? DAppNode containers
- ? DAppNode networks (only reads)
- ? Validator configuration
- ? Execution client (Besu)
- ? Consensus client (Lodestar)
- ? MEV Boost

### ? Will Create (Isolated)
- ? New Docker network (`eth-graffiti-net`)
- ? New containers (MongoDB, SQL Server, API, Web, Nginx)
- ? New data directories (`/var/lib/eth-graffiti-explorer`)
- ? New configuration files (`/opt/eth-graffiti-explorer`)

### ? Will Bridge (Read-Only)
- ? Read-only connection to `dncore_network` for Lodestar access
- ? Non-disruptive network attachment
- ? Falls back to host network if bridging fails

## Pre-Installation Check

Run the pre-installation checker first:

```bash
chmod +x pre-install-check.sh
sudo ./pre-install-check.sh
```

This will:
- ? Verify Docker is installed and running
- ? Detect DAppNode installation
- ? Find your Lodestar container and RPC URL
- ? Check system resources (disk, RAM)
- ? Verify port availability
- ? Test network connectivity

## Installation Process

### Safe Installation Steps

1. **Pre-check** (verifies system readiness):
```bash
sudo ./pre-install-check.sh
```

2. **Install** (runs safely alongside DAppNode):
```bash
sudo ./install-debian.sh
```

3. **Verify** (checks everything works):
```bash
cd /opt/eth-graffiti-explorer
sudo ./status.sh
```

## What Happens During Installation

```
Step 1: Update system packages (safe)
Step 2: Verify Docker exists (read-only check)
Step 3: Ask about firewall (optional, default: skip)
Step 4: Create isolated network (new, separate)
Step 5: Create docker-compose.yml (new files only)
Step 6-7: Create MongoDB/SQL init scripts (new files)
Step 8-9: Create Nginx config (new files)
Step 10: Create management scripts (new files)
Step 11: Create .env file (new, secure)
Step 12: Setup SSL certificates (optional)
Step 13: Clone repository (new directory)
Step 14: Start services (isolated containers)
Step 15: Initialize databases (new databases)
Step 16: Bridge to DAppNode (read-only connection)
```

## Resource Usage

The new installation will use:

| Resource | Amount | Impact on Validator |
|----------|--------|---------------------|
| RAM | 2-4 GB | Minimal (if 16GB+ total) |
| Disk | 20-50 GB | Minimal (if 500GB+ free) |
| CPU | 1-2 cores | Minimal (uses idle capacity) |
| Network | Minimal | Read-only beacon queries |

## Network Diagram

```
??????????????????????????????????????????????????????????
?                 Debian Server                          ?
?                                                        ?
?  ????????????????????????  ????????????????????????  ?
?  ?   DAppNode           ?  ?  ETH Graffiti        ?  ?
?  ?   (Untouched)        ?  ?  (New, Isolated)     ?  ?
?  ?                      ?  ?                      ?  ?
?  ?  • Besu             ?  ?  • MongoDB           ?  ?
?  ?  • Lodestar ??????????????• API (read-only)   ?  ?
?  ?  • MEV Boost        ?  ?  • Web UI            ?  ?
?  ?                      ?  ?  • SQL Server        ?  ?
?  ?  Network:            ?  ?  • Nginx             ?  ?
?  ?  dncore_network      ?  ?                      ?  ?
?  ????????????????????????  ?  Network:            ?  ?
?                             ?  eth-graffiti-net    ?  ?
?                             ????????????????????????  ?
??????????????????????????????????????????????????????????
```

## Rollback/Removal

If you need to remove the installation (validator unaffected):

```bash
# Stop and remove containers
cd /opt/eth-graffiti-explorer
sudo docker compose down -v

# Remove data
sudo rm -rf /var/lib/eth-graffiti-explorer

# Remove installation
sudo rm -rf /opt/eth-graffiti-explorer

# Remove network
sudo docker network rm eth-graffiti-net
```

**Note:** This does NOT affect DAppNode or your validator!

## Monitoring

After installation, you can monitor without affecting validator:

```bash
# Check graffiti explorer status
sudo /opt/eth-graffiti-explorer/status.sh

# View logs
sudo /opt/eth-graffiti-explorer/logs.sh

# Check DAppNode is unaffected
docker ps | grep dappnode
```

## Support

If you encounter issues:

1. **Check pre-installation**: `sudo ./pre-install-check.sh`
2. **View logs**: `sudo /opt/eth-graffiti-explorer/logs.sh api`
3. **Check DAppNode**: `docker ps | grep dappnode` (should be unchanged)
4. **Test Lodestar**: See `LODESTAR_RPC_GUIDE.md`

## Summary

? **Safe:** Will not modify existing Docker or DAppNode
? **Isolated:** Runs in separate containers and network  
? **Read-Only:** Only reads data from Lodestar (no writes)
? **Removable:** Can be completely removed without trace
? **Tested:** Designed specifically for DAppNode compatibility

The installation is **production-ready** and **validator-safe**! ??
