# ETH Graffiti Explorer - Quick Reference Card

## ?? One-Line Install (DAppNode/Debian)

```bash
wget https://raw.githubusercontent.com/nucleoid/EthGraffitiExplorer/main/setup.sh && chmod +x setup.sh && ./setup.sh && sudo ./pre-install-check.sh
```

## ?? Three-Step Installation

```bash
# 1. Setup
./setup.sh

# 2. Pre-check (finds your Lodestar RPC)
sudo ./pre-install-check.sh

# 3. Install (safe for validators)
sudo ./install-debian.sh
```

## ?? What You'll Need

| Requirement | Example | Where to Get |
|-------------|---------|--------------|
| **Domain** | `myvalidator.duckdns.org` | [DuckDNS](https://duckdns.org) (free) |
| **Email** | `user@example.com` | Your email |
| **Lodestar RPC** | `http://172.33.1.5:9596` | Auto-detected by pre-check |
| **SQL Password** | `MyStr0ng!Pass123` | Create strong password |
| **Mongo Password** | `MyStr0ng!Pass456` | Create strong password |

## ?? Finding Lodestar RPC URL

```bash
# Auto-detect (recommended)
sudo ./pre-install-check.sh

# Manual check
docker ps | grep lodestar
docker inspect <container> | grep IPv4Address

# Common URLs:
# - http://lodestar.dappnode:9596 (DAppNode DNS)
# - http://172.33.1.5:9596 (most common IP)
# - http://host.docker.internal:9596 (host network)
```

## ?? File Locations

```
/opt/eth-graffiti-explorer/     # Installation
/var/lib/eth-graffiti-explorer/ # Data (MongoDB, SQL)
/etc/letsencrypt/               # SSL certificates
```

## ?? Management Commands

```bash
cd /opt/eth-graffiti-explorer

./start.sh        # Start all services
./stop.sh         # Stop all services
./status.sh       # Check status
./logs.sh [svc]   # View logs (api, web, mongodb, sqlserver)
./update.sh       # Update to latest version
./backup.sh       # Backup databases
```

## ?? Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **Web UI** | `https://your-domain.com` | Main interface |
| **API** | `https://your-domain.com/api` | REST API |
| **Swagger** | `https://your-domain.com/swagger` | API docs |
| **MongoDB** | `localhost:27017` | Database (local only) |
| **SQL Server** | `localhost:1433` | Database (local only) |

## ?? Quick Troubleshooting

### Can't reach Lodestar?
```bash
# Test from API container
docker exec eth-graffiti-api curl http://172.33.1.5:9596/eth/v1/node/version

# Check network
docker network inspect dncore_network | grep eth-graffiti-api

# Try alternatives in .env:
sudo nano /opt/eth-graffiti-explorer/.env
# Change BEACON_RPC_URL and restart
```

### SSL certificate failed?
```bash
# Stop nginx
docker stop eth-graffiti-nginx

# Get certificate manually
sudo certbot certonly --standalone -d your-domain.com

# Restart nginx
docker start eth-graffiti-nginx
```

### Containers won't start?
```bash
# View logs
sudo ./logs.sh

# Check if ports available
sudo ss -tuln | grep -E ':(80|443|27017|1433)'

# Restart services
sudo docker compose down
sudo docker compose up -d
```

### Validator affected?
```bash
# Should never happen, but verify:
docker ps | grep dappnode        # DAppNode running?
docker logs <lodestar-container> # Check for errors
# If issues, stop graffiti explorer:
cd /opt/eth-graffiti-explorer
sudo docker compose down
```

## ?? Resource Monitoring

```bash
# Container stats
docker stats

# Disk usage
df -h /var/lib/eth-graffiti-explorer

# View logs for errors
sudo ./logs.sh api | grep -i error
```

## ??? Complete Removal

```bash
# Stop and remove everything
cd /opt/eth-graffiti-explorer
sudo docker compose down -v

# Remove data
sudo rm -rf /var/lib/eth-graffiti-explorer

# Remove installation
sudo rm -rf /opt/eth-graffiti-explorer

# Remove network
sudo docker network rm eth-graffiti-net

# Verify validator unaffected
docker ps | grep dappnode
```

## ? Success Indicators

```bash
# All containers running
$ sudo docker compose ps
NAME                    STATUS
eth-graffiti-mongodb    Up 5 minutes
eth-graffiti-sqlserver  Up 5 minutes
eth-graffiti-api        Up 5 minutes
eth-graffiti-web        Up 5 minutes
eth-graffiti-nginx      Up 5 minutes

# Web UI accessible
$ curl -I https://your-domain.com
HTTP/2 200

# API responding
$ curl https://your-domain.com/api/beacon/health
{"status":"healthy"}

# DAppNode unaffected
$ docker ps | grep dappnode
# Shows all DAppNode containers running
```

## ?? Documentation

| File | Purpose |
|------|---------|
| `README.md` | Project overview |
| `INSTALLATION_SUMMARY.md` | Complete summary |
| `DAPPNODE_COMPATIBILITY.md` | Safety details |
| `LODESTAR_RPC_GUIDE.md` | Finding RPC URL |
| `DEPLOYMENT_DEBIAN.md` | Full deployment |
| `CONFIGURATION.md` | Config options |

## ?? Get Help

1. **Read docs** - Most issues covered in guides
2. **Check logs** - `sudo ./logs.sh [service]`
3. **Run pre-check** - `sudo ./pre-install-check.sh`
4. **GitHub Issues** - Open an issue with logs
5. **Verify validator** - `docker ps | grep dappnode`

## ?? Common Use Cases

### Initial Data Sync
```bash
curl -X POST https://your-domain.com/api/beacon/sync
# Watch progress
sudo ./logs.sh api
```

### Search Graffiti
```bash
curl -X POST https://your-domain.com/api/graffiti/search \
  -H "Content-Type: application/json" \
  -d '{"searchTerm":"poap","pageSize":10}'
```

### Get Recent Graffiti
```bash
curl https://your-domain.com/api/graffiti/recent?count=10
```

### View Validator's Graffiti
```bash
curl https://your-domain.com/api/graffiti/validator/12345
```

## ?? Security Checklist

- [ ] Used strong passwords for SQL & MongoDB
- [ ] SSL certificate installed and working
- [ ] Firewall rules configured (ports 80, 443)
- [ ] Database ports only on localhost (27017, 1433)
- [ ] `.env` file has restricted permissions (600)
- [ ] Regular backups configured (`./backup.sh`)
- [ ] Monitoring logs for errors

## ?? Backup Strategy

```bash
# Manual backup
sudo ./backup.sh

# Automated daily backup (cron)
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/eth-graffiti-explorer/backup.sh") | crontab -

# Verify backup
ls -lh /backup/eth-graffiti-explorer/
```

## ?? Update Procedure

```bash
cd /opt/eth-graffiti-explorer

# Backup first
sudo ./backup.sh

# Update
sudo ./update.sh

# Verify
sudo ./status.sh
```

---

**Version**: 1.0.0-dappnode  
**Last Updated**: 2024  
**Support**: [GitHub Issues](https://github.com/nucleoid/EthGraffitiExplorer/issues)

**Safe for DAppNode Validators** ?
