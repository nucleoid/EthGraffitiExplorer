# ETH Graffiti Explorer - Debian Server Deployment Guide

## Overview

This guide provides complete instructions for deploying the ETH Graffiti Explorer on your Debian 12 (Bookworm) validator server running DAppNode with Besu + Lodestar.

## Architecture

```
???????????????????????????????????????????????????????????????
?                    Debian 12 Server                          ?
?                                                              ?
?  ??????????????????      ????????????????????????????????  ?
?  ?   DAppNode     ?      ?  ETH Graffiti Explorer       ?  ?
?  ?                ?      ?                              ?  ?
?  ?  ????????????  ?      ?  ?????????????????????????? ?  ?
?  ?  ?  Besu    ?  ?      ?  ?  Docker Containers     ? ?  ?
?  ?  ?  (EL)    ?  ?      ?  ?                        ? ?  ?
?  ?  ????????????  ?      ?  ?  • MongoDB (Graffiti)  ? ?  ?
?  ?                ?      ?  ?  • SQL Server (Data)   ? ?  ?
?  ?  ????????????  ???RPC??  ?  • API (.NET 8)        ? ?  ?
?  ?  ? Lodestar ?  ?      ?  ?  • Web UI (Blazor)     ? ?  ?
?  ?  ?  (CL)    ?  ?      ?  ?  • Nginx (Proxy)       ? ?  ?
?  ?  ????????????  ?      ?  ?????????????????????????? ?  ?
?  ?                ?      ?                              ?  ?
?  ?  ????????????  ?      ?  ?????????????????????????? ?  ?
?  ?  ?MEV Boost ?  ?      ?  ?   Let's Encrypt SSL    ? ?  ?
?  ?  ????????????  ?      ?  ?????????????????????????? ?  ?
?  ??????????????????      ????????????????????????????????  ?
?                                                              ?
???????????????????????????????????????????????????????????????
                            ?
                            ?
                      Internet / Users
```

## Prerequisites

- Debian 12 (Bookworm) server
- DAppNode with Besu + Lodestar running
- Root or sudo access
- Domain name pointing to your server
- At least 4GB RAM available (in addition to validator requirements)
- 50GB free disk space

## Quick Installation

### Option 1: Automated Installation (Recommended for DAppNode)

```bash
# Download the installation scripts
wget https://raw.githubusercontent.com/nucleoid/EthGraffitiExplorer/main/setup.sh
wget https://raw.githubusercontent.com/nucleoid/EthGraffitiExplorer/main/pre-install-check.sh
wget https://raw.githubusercontent.com/nucleoid/EthGraffitiExplorer/main/install-debian.sh

# Make setup script executable
chmod +x setup.sh

# Run setup helper
./setup.sh

# Run pre-installation check
sudo ./pre-install-check.sh

# If all checks pass, run installation
sudo ./install-debian.sh
```

The pre-check will:
- ? Verify Docker is installed (won't reinstall)
- ? Detect your DAppNode setup
- ? Find your Lodestar RPC URL automatically
- ? Check system resources
- ? Ensure validator won't be affected

The installation script will prompt you for:
- Domain name (optional - press Enter to skip SSL)
- SSL email (if using domain)
- Lodestar beacon node RPC URL (auto-detected by pre-check)
- SQL Server SA password (must be strong)
- MongoDB admin password (must be strong)

### Option 2: Manual Installation

Follow the step-by-step instructions below.

## Manual Installation Steps

### 1. Update System

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### 2. Install Docker

```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install dependencies
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```

### 3. Find Your Lodestar RPC Endpoint

DAppNode typically exposes Lodestar on:
- Internal: `http://172.33.1.5:9596` (check with `docker network inspect dncore_network`)
- Or: `http://lodestar.dappnode:9596`

Test connectivity:
```bash
curl http://172.33.1.5:9596/eth/v1/node/version
```

### 4. Clone Repository

```bash
sudo mkdir -p /opt/eth-graffiti-explorer
cd /opt/eth-graffiti-explorer
sudo git clone https://github.com/nucleoid/EthGraffitiExplorer.git .
```

### 5. Configure Environment

Create `.env` file:
```bash
sudo nano .env
```

Add configuration:
```env
# Database Passwords
SQL_PASSWORD=YourStrongSQLPassword123!
MONGO_PASSWORD=YourStrongMongoPassword123!

# Beacon Node Configuration
BEACON_RPC_URL=http://172.33.1.5:9596

# Domain Configuration
DOMAIN_NAME=graffiti.yourdomain.com

# Data Directory
DATA_DIR=/var/lib/eth-graffiti-explorer
```

### 6. Create Data Directories

```bash
sudo mkdir -p /var/lib/eth-graffiti-explorer/mongodb
sudo mkdir -p /var/lib/eth-graffiti-explorer/sqlserver
sudo mkdir -p /var/lib/eth-graffiti-explorer/nginx/ssl
```

### 7. Deploy with Docker Compose

```bash
cd /opt/eth-graffiti-explorer

# Start services
sudo docker compose up -d

# Check status
sudo docker compose ps

# View logs
sudo docker compose logs -f
```

### 8. Initialize Databases

Wait for SQL Server to start (30-60 seconds), then:

```bash
# Initialize SQL Server
sudo docker exec eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "YourStrongSQLPassword123!" \
  -i /docker-entrypoint-initdb.d/schema.sql
```

MongoDB will initialize automatically.

### 9. Setup SSL with Let's Encrypt

```bash
# Install certbot
sudo apt-get install -y certbot

# Obtain certificate
sudo certbot certonly --standalone \
  --agree-tos \
  --email your-email@example.com \
  -d graffiti.yourdomain.com

# Setup auto-renewal
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && docker restart eth-graffiti-nginx") | crontab -
```

### 10. Configure Firewall

```bash
# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall (if not already)
sudo ufw enable
```

## DAppNode Integration

### Connecting to Lodestar

The API container needs to communicate with your Lodestar beacon node. There are three methods:

#### Method 1: DAppNode Network Bridge (Recommended)

```bash
# Connect API container to DAppNode network
sudo docker network connect dncore_network eth-graffiti-api

# Verify connection
sudo docker exec eth-graffiti-api ping -c 3 lodestar.dappnode
```

#### Method 2: Host Network Access

Use the internal DAppNode IP:
```bash
BEACON_RPC_URL=http://172.33.1.5:9596
```

#### Method 3: Port Forwarding

Expose Lodestar port on the host (less secure):
```bash
# In DAppNode, configure Lodestar to bind to 0.0.0.0:9596
# Then use: BEACON_RPC_URL=http://host.docker.internal:9596
```

### Finding DAppNode Internal IPs

```bash
# List DAppNode containers
docker ps --filter network=dncore_network --format "table {{.Names}}\t{{.Ports}}"

# Inspect network
docker network inspect dncore_network | grep -A 3 lodestar
```

## Configuration

### Lodestar Beacon API Configuration

Ensure Lodestar REST API is enabled in DAppNode:
1. Go to DAppNode UI ? Lodestar
2. Enable "Beacon API"
3. Note the RPC URL (typically `http://172.33.1.5:9596`)

### Performance Tuning

Edit `docker-compose.yml` to adjust resource limits:

```yaml
services:
  mongodb:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          memory: 512M

  sqlserver:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### Monitoring

```bash
# View all logs
sudo docker compose logs -f

# View specific service logs
sudo docker compose logs -f api
sudo docker compose logs -f mongodb

# Check resource usage
docker stats
```

## Management Commands

Create management scripts in `/opt/eth-graffiti-explorer/`:

### Start Services
```bash
#!/bin/bash
cd /opt/eth-graffiti-explorer
docker compose up -d
```

### Stop Services
```bash
#!/bin/bash
cd /opt/eth-graffiti-explorer
docker compose down
```

### Backup Databases
```bash
#!/bin/bash
BACKUP_DIR="/backup/eth-graffiti-$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup MongoDB
docker exec eth-graffiti-mongodb mongodump --out=/tmp/backup
docker cp eth-graffiti-mongodb:/tmp/backup $BACKUP_DIR/mongodb

# Backup SQL Server
docker exec eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "$SQL_PASSWORD" \
  -Q "BACKUP DATABASE EthGraffitiExplorer TO DISK = '/tmp/backup.bak'"
docker cp eth-graffiti-sqlserver:/tmp/backup.bak $BACKUP_DIR/sqlserver.bak

echo "Backup completed: $BACKUP_DIR"
```

## Initial Data Sync

Once services are running, trigger the initial graffiti sync:

```bash
# Method 1: Using curl
curl -X POST https://graffiti.yourdomain.com/api/beacon/sync

# Method 2: Using Swagger UI
# Visit: https://graffiti.yourdomain.com/swagger
# Navigate to BeaconController ? POST /api/beacon/sync ? Try it out
```

The sync will:
1. Connect to your Lodestar beacon node
2. Fetch finalized blocks
3. Extract and decode graffiti
4. Store in MongoDB
5. Update validator information in SQL Server

## Accessing the Application

- **Web UI**: https://graffiti.yourdomain.com
- **API**: https://graffiti.yourdomain.com/api
- **Swagger**: https://graffiti.yourdomain.com/swagger

## Troubleshooting

### Cannot Connect to Lodestar

**Problem**: API cannot reach Lodestar beacon node

**Solutions**:
```bash
# Test connection from host
curl http://172.33.1.5:9596/eth/v1/node/version

# Test from API container
docker exec eth-graffiti-api curl http://172.33.1.5:9596/eth/v1/node/version

# Check if DAppNode network bridge is working
docker network inspect dncore_network | grep eth-graffiti-api

# If not connected, reconnect:
docker network connect dncore_network eth-graffiti-api
docker restart eth-graffiti-api
```

### SQL Server Container Won't Start

**Problem**: SQL Server requires strong password

**Solution**:
```bash
# Password must meet complexity requirements:
# - At least 8 characters
# - Uppercase, lowercase, digits, and symbols
# Example: MyStr0ng!Pass

# Update password in .env file and restart
docker compose down
docker compose up -d
```

### MongoDB Connection Issues

**Problem**: Cannot connect to MongoDB

**Solution**:
```bash
# Check MongoDB logs
docker logs eth-graffiti-mongodb

# Verify MongoDB is running
docker exec eth-graffiti-mongodb mongosh --eval "db.adminCommand('ping')"

# Reset MongoDB (WARNING: Deletes data)
docker compose down
sudo rm -rf /var/lib/eth-graffiti-explorer/mongodb/*
docker compose up -d mongodb
```

### SSL Certificate Issues

**Problem**: Let's Encrypt certificate failed

**Solution**:
```bash
# Ensure domain points to your server
dig +short graffiti.yourdomain.com

# Stop nginx temporarily
docker stop eth-graffiti-nginx

# Obtain certificate
sudo certbot certonly --standalone -d graffiti.yourdomain.com

# Restart nginx
docker start eth-graffiti-nginx
```

### Out of Disk Space

**Problem**: Databases growing too large

**Solutions**:
```bash
# Check disk usage
df -h
docker system df

# Clean old Docker images
docker image prune -a

# Archive old graffiti (MongoDB)
docker exec eth-graffiti-mongodb mongosh EthGraffitiExplorer --eval \
  "db.graffiti.deleteMany({timestamp: {\$lt: new Date('2023-01-01')}})"

# Compact MongoDB
docker exec eth-graffiti-mongodb mongosh EthGraffitiExplorer --eval "db.runCommand({compact: 'graffiti'})"
```

## Security Best Practices

1. **Change Default Passwords**: Use strong, unique passwords for databases
2. **Firewall Rules**: Only expose ports 80/443 externally
3. **Regular Updates**: Keep Docker and containers updated
4. **SSL Only**: Never allow HTTP access in production
5. **Database Access**: Restrict to localhost only (127.0.0.1)
6. **Backups**: Implement regular automated backups
7. **Monitoring**: Set up alerts for service failures

## Performance Optimization

### MongoDB Tuning

```javascript
// Connect to MongoDB
docker exec -it eth-graffiti-mongodb mongosh

use EthGraffitiExplorer

// Enable profiling
db.setProfilingLevel(1, { slowms: 100 })

// Check slow queries
db.system.profile.find().sort({ts:-1}).limit(5).pretty()

// Analyze index usage
db.graffiti.aggregate([{ $indexStats: {} }])
```

### SQL Server Tuning

```sql
-- Connect to SQL Server
docker exec -it eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa

-- Check index fragmentation
SELECT OBJECT_NAME(ips.object_id) AS TableName,
       ips.index_id,
       ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
WHERE ips.avg_fragmentation_in_percent > 30;

-- Rebuild fragmented indexes
ALTER INDEX ALL ON Validators REBUILD;
ALTER INDEX ALL ON BeaconBlocks REBUILD;
```

## Upgrading

To upgrade to the latest version:

```bash
cd /opt/eth-graffiti-explorer

# Backup first!
./backup.sh

# Pull latest code
git pull

# Rebuild containers
docker compose build --no-cache

# Restart services
docker compose down
docker compose up -d

# Check logs
docker compose logs -f
```

## Uninstallation

To completely remove the installation:

```bash
# Stop services
cd /opt/eth-graffiti-explorer
docker compose down -v

# Remove containers and images
docker rmi $(docker images 'eth-graffiti*' -q)

# Remove data (WARNING: Permanent)
sudo rm -rf /var/lib/eth-graffiti-explorer

# Remove installation
sudo rm -rf /opt/eth-graffiti-explorer

# Remove systemd service
sudo systemctl disable eth-graffiti-explorer
sudo rm /etc/systemd/system/eth-graffiti-explorer.service
sudo systemctl daemon-reload
```

## Support

For issues or questions:
- GitHub Issues: https://github.com/nucleoid/EthGraffitiExplorer/issues
- Documentation: See README.md and CONFIGURATION.md

## License

MIT License
