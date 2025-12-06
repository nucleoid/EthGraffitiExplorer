# Troubleshooting: Web App "Error" Page

## The Problem

When navigating to `/graffiti`, you see:
```
Error.
An error occurred while processing your request.
```

## Quick Diagnosis

Run the diagnostic script:
```sh
cd /opt/eth-graffiti-explorer
sudo chmod +x diagnose-issue.sh
sudo ./diagnose-issue.sh
```

## Most Common Causes

### 1. API Container Not Running or Crashed

**Check:**
```sh
docker ps | grep eth-graffiti-api
docker logs eth-graffiti-api --tail=50
```

**Fix:**
```sh
cd /opt/eth-graffiti-explorer
sudo docker compose restart api
sudo docker logs -f eth-graffiti-api
```

### 2. Database Connection Failed

**Symptoms:**
- API logs show database connection errors
- SQL Server or MongoDB is unhealthy

**Check:**
```sh
# Check SQL Server
docker exec eth-graffiti-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourPassword" -Q "SELECT 1" -C

# Check MongoDB
docker exec eth-graffiti-mongodb mongosh --eval "db.adminCommand('ping')"
```

**Fix:**
```sh
# Restart databases
cd /opt/eth-graffiti-explorer
sudo docker compose restart mongodb sqlserver

# Wait 30 seconds
sleep 30

# Restart API
sudo docker compose restart api
```

### 3. Missing Database Migration

**Symptoms:**
- API logs show "table does not exist" or similar errors

**Fix:**
```sh
# The API should run migrations automatically
# Force restart to trigger migrations
cd /opt/eth-graffiti-explorer
sudo docker compose restart api
sudo docker logs -f eth-graffiti-api
```

Look for: `Applied migration` or `Database migration complete`

### 4. Web Container Can't Reach API

**Check:**
```sh
docker exec eth-graffiti-web curl -v http://api:80/health
```

**Fix:**
```sh
# Recreate containers with proper network
cd /opt/eth-graffiti-explorer
sudo docker compose down
sudo docker compose up -d
```

### 5. No Data in Database

**Check:**
```sh
docker exec eth-graffiti-mongodb mongosh EthGraffitiExplorer --eval "db.graffiti.countDocuments()"
```

**Fix:**
```sh
# Trigger initial sync
curl -X POST http://localhost:8080/api/beacon/sync

# Or via the running container
docker exec eth-graffiti-api curl -X POST http://localhost:80/api/beacon/sync
```

## Step-by-Step Diagnosis

### Step 1: Check All Containers Are Running

```sh
docker ps --filter "name=eth-graffiti"
```

Expected output:
```
NAME                     STATUS
eth-graffiti-mongodb     Up 10 minutes (healthy)
eth-graffiti-sqlserver   Up 10 minutes (healthy)
eth-graffiti-api         Up 10 minutes
eth-graffiti-web         Up 10 minutes
eth-graffiti-nginx       Up 10 minutes
```

If any container is not "Up" or shows "Restarting", check its logs:
```sh
docker logs eth-graffiti-<container-name>
```

### Step 2: Check API Health

```sh
curl http://localhost:8080/health
# or
curl http://localhost:5000/health
```

Expected: `{"status":"Healthy"}` or similar

If this fails, the API is not responding. Check logs:
```sh
docker logs eth-graffiti-api --tail=100
```

### Step 3: Check Database Connections

**MongoDB:**
```sh
docker exec eth-graffiti-mongodb mongosh --quiet --eval "db.adminCommand('ping')"
```

**SQL Server:**
```sh
docker exec eth-graffiti-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourPassword" -Q "SELECT @@VERSION" -C
```

### Step 4: Test API Endpoint Directly

```sh
curl http://localhost:8080/api/graffiti/recent?count=5
```

Expected: JSON array of graffiti (or empty array if no data)

If you get an error, check the API logs for details.

### Step 5: Check Web Configuration

```sh
docker exec eth-graffiti-web printenv | grep ApiSettings
```

Expected: `ApiSettings__BaseUrl=http://api:80`

If this is wrong, edit docker-compose.yml and restart.

## Common Error Messages in Logs

### "Unable to connect to MongoDB"

**Cause:** MongoDB password mismatch or MongoDB not ready

**Fix:**
```sh
# Check .env file has correct password
cat /opt/eth-graffiti-explorer/.env | grep MONGO_PASSWORD

# Verify MongoDB is using same password
docker exec eth-graffiti-mongodb mongosh -u admin -p "YourPassword" --authenticationDatabase admin --eval "db.adminCommand('ping')"

# If password is wrong, recreate MongoDB with volumes removed
cd /opt/eth-graffiti-explorer
sudo docker compose down
sudo rm -rf /var/lib/eth-graffiti-explorer/mongodb/*
sudo docker compose up -d mongodb
```

### "Cannot connect to SQL Server"

**Cause:** SQL Server password mismatch or SQL Server not ready

**Fix:**
```sh
# Check SQL Server logs
docker logs eth-graffiti-sqlserver | grep -i error

# Verify password
docker exec eth-graffiti-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "YourPassword" -Q "SELECT 1" -C

# If password is wrong, recreate SQL Server
cd /opt/eth-graffiti-explorer
sudo docker compose down
sudo rm -rf /var/lib/eth-graffiti-explorer/sqlserver/*
sudo docker compose up -d sqlserver
```

### "Table 'Validators' doesn't exist"

**Cause:** Entity Framework migrations haven't run

**Fix:**
```sh
# Restart API to trigger migrations
sudo docker compose restart api
sudo docker logs -f eth-graffiti-api

# Look for migration messages
```

### "Unable to reach beacon node"

**Cause:** Beacon node URL is incorrect or beacon node is not accessible

**Fix:**
```sh
# Check beacon node URL
docker exec eth-graffiti-api printenv | grep BeaconNode__Url

# Test from API container
docker exec eth-graffiti-api curl -v http://lodestar.dappnode:9596/eth/v1/node/version

# Update URL if needed
sudo nano /opt/eth-graffiti-explorer/docker-compose.yml
# Change BeaconNode__Url to correct value
sudo docker compose up -d
```

## Full Reset (Nuclear Option)

If nothing else works, completely reset the installation:

```sh
cd /opt/eth-graffiti-explorer

# Stop all containers
sudo docker compose down -v

# Remove all data (WARNING: This deletes all graffiti data!)
sudo rm -rf /var/lib/eth-graffiti-explorer/mongodb/*
sudo rm -rf /var/lib/eth-graffiti-explorer/sqlserver/*

# Rebuild and start
sudo docker compose build --no-cache
sudo docker compose up -d

# Wait for everything to be ready
sleep 60

# Check status
sudo ./status.sh
```

## Enable Development Mode (Temporary)

To see the actual error message, temporarily enable development mode:

```sh
# Edit docker-compose.yml
sudo nano /opt/eth-graffiti-explorer/docker-compose.yml

# Find the web service and change:
# ASPNETCORE_ENVIRONMENT: Production
# to:
# ASPNETCORE_ENVIRONMENT: Development

# Restart web
sudo docker compose restart web

# Now visit http://localhost:8080/graffiti again
# You'll see the detailed error message
```

**Remember to change back to Production after debugging!**

## Getting Help

If you're still stuck:

1. Run the diagnostic script and save output:
```sh
cd /opt/eth-graffiti-explorer
sudo ./diagnose-issue.sh > diagnostic.txt 2>&1
```

2. Collect logs:
```sh
sudo docker logs eth-graffiti-api > api.log 2>&1
sudo docker logs eth-graffiti-web > web.log 2>&1
```

3. Share the diagnostic output and logs for further help

## Prevention

After fixing, verify everything works:

```sh
# 1. Check all services
sudo ./status.sh

# 2. Test API
curl http://localhost:8080/api/graffiti/recent?count=1

# 3. Test Web UI
open http://localhost:8080

# 4. Trigger sync if no data
curl -X POST http://localhost:8080/api/beacon/sync
```
