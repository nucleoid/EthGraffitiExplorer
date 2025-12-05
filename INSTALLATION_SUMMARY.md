# ETH Graffiti Explorer - Installation Summary

## ? Changes Made for DAppNode Compatibility

The installation script has been **completely rewritten** to be 100% safe for DAppNode validators. Here's what changed:

### What Was Changed

| Component | Old Behavior | New Behavior | Why |
|-----------|--------------|--------------|-----|
| **Docker Install** | Removed & reinstalled Docker | Only verifies Docker exists | Prevents disrupting DAppNode |
| **Firewall** | Force-enabled UFW | Optional, asks permission | Prevents breaking validator connectivity |
| **Network** | Could conflict with DAppNode | Creates isolated network first | Avoids network conflicts |
| **DAppNode Detection** | None | Detects and validates | Ensures safe operation |
| **Connectivity Test** | None | Tests Lodestar connection | Provides helpful troubleshooting |

### What You Get

**3 New Files Created:**

1. **`pre-install-check.sh`** - Run FIRST to verify your system
   - Detects DAppNode automatically
   - Finds your Lodestar RPC URL
   - Checks system resources
   - Validates prerequisites

2. **`install-debian.sh`** - Modified to be DAppNode-safe
   - Won't touch existing Docker
   - Creates isolated environment
   - Bridges safely to DAppNode
   - Tests connectivity

3. **`setup.sh`** - Quick helper
   - Makes scripts executable
   - Shows next steps
   - Provides guidance

**3 New Documentation Files:**

1. **`DAPPNODE_COMPATIBILITY.md`** - Safety guarantees and architecture
2. **`LODESTAR_RPC_GUIDE.md`** - How to find your Lodestar RPC URL  
3. **`DEPLOYMENT_DEBIAN.md`** - Updated with DAppNode instructions

## ?? Quick Start (3 Commands)

```bash
# 1. Setup
wget https://raw.githubusercontent.com/nucleoid/EthGraffitiExplorer/main/setup.sh
chmod +x setup.sh && ./setup.sh

# 2. Pre-check
sudo ./pre-install-check.sh

# 3. Install
sudo ./install-debian.sh
```

## ??? Safety Guarantees

### Will NOT Touch:
- ? Docker installation
- ? DAppNode containers
- ? DAppNode networks (only reads)
- ? Validator configuration
- ? Besu execution client
- ? Lodestar consensus client
- ? MEV Boost
- ? Firewall (asks first)

### Will Create (Isolated):
- ? New network (`eth-graffiti-net`)
- ? New containers (MongoDB, SQL, API, Web, Nginx)
- ? New data dirs (`/var/lib/eth-graffiti-explorer`)
- ? New config (`/opt/eth-graffiti-explorer`)

### Will Read (Non-Disruptive):
- ? Lodestar beacon chain data via RPC
- ? DAppNode network (read-only bridge)

## ?? What Gets Installed

```
/opt/eth-graffiti-explorer/          # Installation directory
??? docker-compose.yml               # Container orchestration
??? Dockerfile.api                   # API container build
??? Dockerfile.web                   # Web container build
??? mongo-init.js                    # MongoDB initialization
??? SqlServer_Schema.sql             # SQL Server schema
??? nginx.conf                       # Nginx main config
??? nginx-site.conf                  # Site-specific config
??? .env                             # Secure credentials
??? start.sh                         # Start services
??? stop.sh                          # Stop services
??? status.sh                        # Check status
??? logs.sh                          # View logs
??? update.sh                        # Update to latest
??? backup.sh                        # Backup databases

/var/lib/eth-graffiti-explorer/      # Data directory
??? mongodb/                         # MongoDB data
??? sqlserver/                       # SQL Server data
??? nginx/ssl/                       # SSL certificates

Docker Containers Created:
??? eth-graffiti-mongodb             # Graffiti storage
??? eth-graffiti-sqlserver           # Relational data
??? eth-graffiti-api                 # .NET API
??? eth-graffiti-web                 # Blazor UI
??? eth-graffiti-nginx               # Reverse proxy
```

## ?? Network Architecture

```
??????????????????????????????????????????????????????????
?                    Debian Server                       ?
?                                                        ?
?  ????????????????????        ???????????????????????   ?
?  ?   DAppNode       ?        ?  ETH Graffiti       ?   ?
?  ?                  ?        ?  Explorer           ?   ?
?  ?  ??????????????  ?        ?                     ?   ?
?  ?  ?   Besu     ?  ?        ?  ?????????????????  ?   ?
?  ?  ? (Execution)?  ?        ?  ?   MongoDB     ?  ?   ?
?  ?  ??????????????  ?        ?  ?  (Graffiti)   ?  ?   ?
?  ?                  ?        ?  ?????????????????  ?   ?
?  ?  ??????????????  ?  RPC   ?                     ?   ?
?  ?  ?  Lodestar  ?????????????  ?????????????????  ?   ?
?  ?  ? (Consensus)?  ?  9596  ?  ?      API      ?  ?   ?
?  ?  ??????????????  ?        ?  ?  (.NET 8)     ?  ?   ?
?  ?                  ?        ?  ?????????????????  ?   ?
?  ?  ??????????????  ?        ?                     ?   ?
?  ?  ? MEV Boost  ?  ?        ?  ?????????????????  ?   ?
?  ?  ??????????????  ?        ?  ?  SQL Server   ?  ?   ?
?  ?                  ?        ?  ?  (Metadata)   ?  ?   ?
?  ?  Network:        ?        ?  ?????????????????  ?   ?
?  ?  dncore_network  ?        ?                     ?   ?
?  ????????????????????        ?  Network:           ?   ?
?                              ?  eth-graffiti-net   ?   ?
?                              ???????????????????????   ?
?                                                        ?
??????????????????????????????????????????????????????????
                              ?
                              ?
                         Internet
                    (via Nginx SSL proxy)
```

## ?? Pre-Installation Checklist

Run `sudo ./pre-install-check.sh` to verify:

- [x] Docker installed and running
- [x] DAppNode detected
- [x] Lodestar container found
- [x] Lodestar RPC URL identified
- [x] Sufficient disk space (50GB+)
- [x] Sufficient RAM (4GB+ free)
- [x] Ports available (80, 443)
- [x] Internet connectivity

## ?? Installation Flow

```
1. pre-install-check.sh
   ??> Verifies system
   ??> Detects DAppNode
   ??> Finds Lodestar RPC
   ??> Shows recommendations

2. install-debian.sh
   ??> Verifies Docker (no install)
   ??> Asks about firewall (optional)
   ??> Creates isolated network
   ??> Generates config files
   ??> Obtains SSL certificate
   ??> Builds containers
   ??> Initializes databases
   ??> Bridges to DAppNode (safe)
   ??> Tests connectivity

3. Post-Installation
   ??> Access web UI
   ??> Trigger initial sync
   ??> Monitor logs
   ??> Verify operation
```

## ?? Configuration Examples

### Lodestar RPC URLs (Pick One):

```bash
# DAppNode DNS (recommended)
http://lodestar.dappnode:9596

# DAppNode Internal IP (most common)
http://172.33.1.5:9596

# Host network
http://host.docker.internal:9596
```

### Domain Options:

```bash
# Option 1: Real domain
graffiti.yourdomain.com

# Option 2: DuckDNS (free)
myvalidator.duckdns.org

# Option 3: Skip SSL
[Press Enter]
```

### Database Passwords:

Must be strong (8+ chars, mixed case, numbers, symbols):
```bash
# SQL Server
MyStr0ng!SQLPass123

# MongoDB
MyStr0ng!MongoPass456
```

## ?? Resource Usage

| Resource | Idle | Active | Notes |
|----------|------|--------|-------|
| **RAM** | 2GB | 4GB | Minimal impact if 16GB+ total |
| **Disk** | 10GB | 50GB | Grows with graffiti history |
| **CPU** | <5% | <15% | Only during sync/queries |
| **Network** | <1KB/s | 10KB/s | Read-only beacon queries |

## ?? Management Commands

```bash
# Start
sudo /opt/eth-graffiti-explorer/start.sh

# Stop
sudo /opt/eth-graffiti-explorer/stop.sh

# Status
sudo /opt/eth-graffiti-explorer/status.sh

# Logs
sudo /opt/eth-graffiti-explorer/logs.sh [service]

# Update
sudo /opt/eth-graffiti-explorer/update.sh

# Backup
sudo /opt/eth-graffiti-explorer/backup.sh
```

## ?? Complete Removal

If you need to remove everything (validator unaffected):

```bash
cd /opt/eth-graffiti-explorer
sudo docker compose down -v
sudo rm -rf /var/lib/eth-graffiti-explorer
sudo rm -rf /opt/eth-graffiti-explorer
sudo docker network rm eth-graffiti-net
```

## ?? Documentation

| File | Purpose |
|------|---------|
| `README.md` | Project overview |
| `DEPLOYMENT_DEBIAN.md` | Full deployment guide |
| `DAPPNODE_COMPATIBILITY.md` | Safety and compatibility |
| `LODESTAR_RPC_GUIDE.md` | Finding Lodestar RPC URL |
| `CONFIGURATION.md` | Configuration options |
| `SETUP.md` | Setup instructions |

## ? Success Criteria

After installation, you should see:

```bash
$ sudo /opt/eth-graffiti-explorer/status.sh

NAME                    STATUS      PORTS
eth-graffiti-mongodb    Up 5 min    127.0.0.1:27017->27017/tcp
eth-graffiti-sqlserver  Up 5 min    127.0.0.1:1433->1433/tcp
eth-graffiti-api        Up 5 min    127.0.0.1:5000->80/tcp
eth-graffiti-web        Up 5 min    127.0.0.1:5001->80/tcp
eth-graffiti-nginx      Up 5 min    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

And verify:
- ? Web UI accessible at `https://your-domain.com`
- ? API responding at `https://your-domain.com/api`
- ? Swagger available at `https://your-domain.com/swagger`
- ? DAppNode containers still running: `docker ps | grep dappnode`

## ?? Troubleshooting

### Issue: Can't reach Lodestar

```bash
# Test from host
curl http://172.33.1.5:9596/eth/v1/node/version

# Test from API container
docker exec eth-graffiti-api curl http://172.33.1.5:9596/eth/v1/node/version

# Check network connection
docker network inspect dncore_network | grep eth-graffiti-api
```

### Issue: SSL certificate failed

```bash
# Stop nginx
docker stop eth-graffiti-nginx

# Manually obtain certificate
sudo certbot certonly --standalone -d your-domain.com

# Restart nginx
docker start eth-graffiti-nginx
```

### Issue: Containers not starting

```bash
# Check logs
sudo /opt/eth-graffiti-explorer/logs.sh

# Restart services
cd /opt/eth-graffiti-explorer
sudo docker compose down
sudo docker compose up -d
```

## ?? Summary

You now have:
- ? Safe installation scripts for DAppNode
- ? Pre-check to validate your system
- ? Comprehensive documentation
- ? Network isolation from validator
- ? Read-only access to Lodestar
- ? Production-ready setup with SSL
- ? Easy management scripts
- ? Complete removal option

**Ready to install?** Run: `sudo ./pre-install-check.sh`

**Questions?** Check the documentation or open an issue on GitHub.

**Happy graffiti exploring!** ??
