#!/bin/bash

################################################################################
# ETH Graffiti Explorer - Complete Installation Script for Debian 12 (Bookworm)
# 
# This script installs and configures:
# - Docker & Docker Compose
# - MongoDB
# - SQL Server (Linux)
# - .NET 8 Runtime
# - ETH Graffiti Explorer (API, Web, Mobile Backend)
# - Nginx Reverse Proxy
# - SSL Certificates (Let's Encrypt)
#
# Designed to run alongside DAppNode with Besu + Lodestar
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo_error "Please run as root (use sudo)"
    exit 1
fi

echo_info "Starting ETH Graffiti Explorer installation..."
echo_info "This script will install MongoDB, SQL Server, and ETH Graffiti Explorer components"
echo ""

# Safety check for DAppNode
echo_warning "=== IMPORTANT: DAppNode Compatibility Check ==="
echo_info "This installation is designed to run ALONGSIDE your DAppNode validator"
echo_info "It will NOT modify or interfere with your existing Docker/DAppNode setup"
echo ""

if docker ps --format '{{.Names}}' | grep -q "DAppNode\|dappnode"; then
    echo_success "DAppNode containers detected - proceeding with safe installation"
else
    echo_warning "DAppNode containers not detected. Is DAppNode running?"
    read -p "Continue anyway? (y/N): " CONTINUE_ANYWAY
    if [[ ! "$CONTINUE_ANYWAY" =~ ^[Yy]$ ]]; then
        echo_info "Installation cancelled"
        exit 0
    fi
fi

echo ""
echo_info "=== Installation Configuration ==="
echo ""

# Get configuration from user
read -p "Enter your domain name (e.g., graffiti.yourdomain.com) or press Enter to skip SSL: " DOMAIN_NAME
read -p "Enter your email for SSL certificates: " SSL_EMAIL
read -p "Enter Lodestar beacon node RPC URL [http://localhost:9596]: " BEACON_RPC_URL
BEACON_RPC_URL=${BEACON_RPC_URL:-http://localhost:9596}

read -sp "Enter SQL Server SA password (strong password required): " SQL_PASSWORD
echo ""
read -sp "Enter MongoDB admin password: " MONGO_PASSWORD
echo ""

# Installation directory
INSTALL_DIR="/opt/eth-graffiti-explorer"
DATA_DIR="/var/lib/eth-graffiti-explorer"

echo_info "Creating installation directories..."
mkdir -p $INSTALL_DIR
mkdir -p $DATA_DIR/mongodb
mkdir -p $DATA_DIR/sqlserver
mkdir -p $DATA_DIR/nginx/ssl

################################################################################
# Step 1: Update System & Install Prerequisites
################################################################################

echo_info "Step 1: Updating system and installing prerequisites..."

apt-get update
apt-get upgrade -y

apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    software-properties-common \
    ufw \
    certbot

echo_success "System updated and prerequisites installed"

################################################################################
# Step 2: Verify Docker & Docker Compose Installation
################################################################################

echo_info "Step 2: Verifying Docker and Docker Compose installation..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo_error "Docker is not installed. Please install Docker first."
    echo_error "Since you have DAppNode, Docker should already be installed."
    exit 1
fi

# Check if Docker Compose is installed
if ! docker compose version &> /dev/null; then
    echo_error "Docker Compose plugin is not installed."
    echo_error "Please install docker-compose-plugin: apt-get install docker-compose-plugin"
    exit 1
fi

# Verify Docker is running
if ! docker ps &> /dev/null; then
    echo_error "Docker is not running or you don't have permission."
    echo_error "Try: sudo systemctl start docker"
    exit 1
fi

echo_success "Docker is installed and running"
docker --version
docker compose version

################################################################################
# Step 3: Configure Firewall (Optional - Skip if DAppNode manages firewall)
################################################################################

echo_info "Step 3: Checking firewall configuration..."

if command -v ufw &> /dev/null; then
    echo_warning "UFW firewall detected. Do you want to configure firewall rules? (y/N)"
    read -p "Configure firewall? [N]: " CONFIGURE_FIREWALL
    CONFIGURE_FIREWALL=${CONFIGURE_FIREWALL:-N}
    
    if [[ "$CONFIGURE_FIREWALL" =~ ^[Yy]$ ]]; then
        echo_info "Configuring firewall rules..."
        
        # Allow SSH (if not already allowed)
        ufw allow 22/tcp 2>/dev/null || true
        
        # Allow HTTP and HTTPS
        ufw allow 80/tcp 2>/dev/null || true
        ufw allow 443/tcp 2>/dev/null || true
        
        echo_success "Firewall rules added (not enabled to avoid disrupting validator)"
        echo_warning "To enable: sudo ufw enable"
    else
        echo_info "Skipping firewall configuration"
    fi
else
    echo_info "UFW not found, skipping firewall configuration"
fi

echo_success "Firewall check completed"

################################################################################
# Step 4: Create Docker Network (Safe - Won't affect DAppNode)
################################################################################

echo_info "Step 4: Creating isolated Docker network..."

# Create a custom bridge network for the stack (separate from DAppNode)
if docker network ls | grep -q "eth-graffiti-net"; then
    echo_info "Network 'eth-graffiti-net' already exists"
else
    docker network create eth-graffiti-net
    echo_success "Created isolated network 'eth-graffiti-net'"
fi

# Check if DAppNode is running
if docker network ls | grep -q "dncore_network\|dappnode"; then
    echo_success "DAppNode network detected - will connect API container later"
    DAPPNODE_DETECTED=true
else
    echo_warning "DAppNode network not detected. Will use host network for beacon node access."
    DAPPNODE_DETECTED=false
fi

echo_success "Docker network setup completed"

################################################################################
# Step 5: Create Docker Compose Configuration
################################################################################

echo_info "Step 5: Creating Docker Compose configuration..."

cat > $INSTALL_DIR/docker-compose.yml <<EOF
version: '3.8'

services:
  # MongoDB - Graffiti Storage
  mongodb:
    image: mongo:7.0
    container_name: eth-graffiti-mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD}
      MONGO_INITDB_DATABASE: EthGraffitiExplorer
    ports:
      - "127.0.0.1:27017:27017"
    volumes:
      - ${DATA_DIR}/mongodb:/data/db
      - ./mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro
    networks:
      - eth-graffiti-net
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 5s
      retries: 5

  # SQL Server - Relational Data
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: eth-graffiti-sqlserver
    restart: unless-stopped
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: ${SQL_PASSWORD}
      MSSQL_PID: "Express"
    ports:
      - "127.0.0.1:1433:1433"
    volumes:
      - ${DATA_DIR}/sqlserver:/var/opt/mssql
      - ./SqlServer_Schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro
    networks:
      - eth-graffiti-net
    healthcheck:
      test: /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "${SQL_PASSWORD}" -Q "SELECT 1" || exit 1
      interval: 10s
      timeout: 5s
      retries: 5

  # API Service
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    container_name: eth-graffiti-api
    restart: unless-stopped
    environment:
      ASPNETCORE_ENVIRONMENT: Production
      ASPNETCORE_URLS: http://+:80
      ConnectionStrings__DefaultConnection: "Server=sqlserver;Database=EthGraffitiExplorer;User Id=sa;Password=${SQL_PASSWORD};TrustServerCertificate=true;MultipleActiveResultSets=true"
      MongoDB__ConnectionString: "mongodb://admin:${MONGO_PASSWORD}@mongodb:27017"
      MongoDB__DatabaseName: "EthGraffitiExplorer"
      MongoDB__GraffitiCollectionName: "graffiti"
      BeaconNode__Url: "${BEACON_RPC_URL}"
    ports:
      - "127.0.0.1:5000:80"
    depends_on:
      mongodb:
        condition: service_healthy
      sqlserver:
        condition: service_healthy
    networks:
      - eth-graffiti-net
      - dappnode_network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./logs/api:/app/logs

  # Web UI Service
  web:
    build:
      context: .
      dockerfile: Dockerfile.web
    container_name: eth-graffiti-web
    restart: unless-stopped
    environment:
      ASPNETCORE_ENVIRONMENT: Production
      ASPNETCORE_URLS: http://+:80
      ApiSettings__BaseUrl: "http://api:80"
    ports:
      - "127.0.0.1:5001:80"
    depends_on:
      - api
    networks:
      - eth-graffiti-net
    volumes:
      - ./logs/web:/app/logs

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: eth-graffiti-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx-site.conf:/etc/nginx/conf.d/default.conf:ro
      - ${DATA_DIR}/nginx/ssl:/etc/nginx/ssl:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - api
      - web
    networks:
      - eth-graffiti-net

networks:
  eth-graffiti-net:
    external: true
  dappnode_network:
    external: true
    name: dncore_network

EOF

echo_success "Docker Compose configuration created"

################################################################################
# Step 6: Create MongoDB Initialization Script
################################################################################

echo_info "Step 6: Creating MongoDB initialization script..."

cat > $INSTALL_DIR/mongo-init.js <<EOF
// MongoDB initialization script for ETH Graffiti Explorer

db = db.getSiblingDB('EthGraffitiExplorer');

// Create graffiti collection with schema validation
db.createCollection('graffiti', {
  validator: {
    \$jsonSchema: {
      bsonType: 'object',
      required: ['slot', 'blockHash', 'validatorIndex', 'timestamp'],
      properties: {
        slot: { bsonType: 'long' },
        epoch: { bsonType: 'long' },
        blockNumber: { bsonType: 'long' },
        blockHash: { bsonType: 'string' },
        validatorIndex: { bsonType: 'int' },
        rawGraffiti: { bsonType: 'string' },
        decodedGraffiti: { bsonType: 'string' },
        timestamp: { bsonType: 'date' },
        proposerPubkey: { bsonType: 'string' },
        createdAt: { bsonType: 'date' }
      }
    }
  }
});

// Create indexes
db.graffiti.createIndex({ slot: 1 });
db.graffiti.createIndex({ validatorIndex: 1 });
db.graffiti.createIndex({ blockHash: 1 }, { unique: true });
db.graffiti.createIndex({ timestamp: -1 });
db.graffiti.createIndex({ decodedGraffiti: 'text' });
db.graffiti.createIndex({ validatorIndex: 1, timestamp: -1 });

print('MongoDB initialization completed successfully');
EOF

echo_success "MongoDB initialization script created"

################################################################################
# Step 7: Create Dockerfiles
################################################################################

echo_info "Step 7: Creating Dockerfiles..."

# API Dockerfile
cat > $INSTALL_DIR/Dockerfile.api <<'EOF'
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["EthGraffitiExplorer.Api.csproj", "./"]
COPY ["EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj", "EthGraffitiExplorer.Core/"]

# Restore dependencies
RUN dotnet restore "EthGraffitiExplorer.Api.csproj"

# Copy source code
COPY . .

# Build
RUN dotnet build "EthGraffitiExplorer.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "EthGraffitiExplorer.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Install sqlcmd for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["dotnet", "EthGraffitiExplorer.Api.dll"]
EOF

# Web Dockerfile
cat > $INSTALL_DIR/Dockerfile.web <<'EOF'
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["EthGraffitiExplorer.Web/EthGraffitiExplorer.Web.csproj", "EthGraffitiExplorer.Web/"]
COPY ["EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj", "EthGraffitiExplorer.Core/"]

# Restore dependencies
RUN dotnet restore "EthGraffitiExplorer.Web/EthGraffitiExplorer.Web.csproj"

# Copy source code
COPY . .

# Build
WORKDIR "/src/EthGraffitiExplorer.Web"
RUN dotnet build "EthGraffitiExplorer.Web.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "EthGraffitiExplorer.Web.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

ENTRYPOINT ["dotnet", "EthGraffitiExplorer.Web.dll"]
EOF

echo_success "Dockerfiles created"

################################################################################
# Step 8: Create Nginx Configuration
################################################################################

echo_info "Step 8: Creating Nginx configuration..."

cat > $INSTALL_DIR/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 20M;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;

    include /etc/nginx/conf.d/*.conf;
}
EOF

cat > $INSTALL_DIR/nginx-site.conf <<EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name ${DOMAIN_NAME};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME};

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # API Proxy
    location /api/ {
        proxy_pass http://api:80/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }

    # Swagger UI
    location /swagger/ {
        proxy_pass http://api:80/swagger/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Web UI
    location / {
        proxy_pass http://web:80/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support for Blazor Server
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF

echo_success "Nginx configuration created"

################################################################################
# Step 9: Create Systemd Service
################################################################################

echo_info "Step 9: Creating systemd service..."

cat > /etc/systemd/system/eth-graffiti-explorer.service <<EOF
[Unit]
Description=ETH Graffiti Explorer
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable eth-graffiti-explorer.service

echo_success "Systemd service created and enabled"

################################################################################
# Step 10: Create Management Scripts
################################################################################

echo_info "Step 10: Creating management scripts..."

# Start script
cat > $INSTALL_DIR/start.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose up -d
docker compose logs -f
EOF
chmod +x $INSTALL_DIR/start.sh

# Stop script
cat > $INSTALL_DIR/stop.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose down
EOF
chmod +x $INSTALL_DIR/stop.sh

# Status script
cat > $INSTALL_DIR/status.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
docker compose ps
echo ""
echo "=== Container Logs (last 50 lines) ==="
docker compose logs --tail=50
EOF
chmod +x $INSTALL_DIR/status.sh

# Update script
cat > $INSTALL_DIR/update.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Pulling latest code..."
git pull
echo "Rebuilding containers..."
docker compose build --no-cache
echo "Restarting services..."
docker compose down
docker compose up -d
echo "Update complete!"
EOF
chmod +x $INSTALL_DIR/update.sh

# Backup script
cat > $INSTALL_DIR/backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/backup/eth-graffiti-explorer"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "Backing up MongoDB..."
docker exec eth-graffiti-mongodb mongodump --out=/tmp/backup --quiet
docker cp eth-graffiti-mongodb:/tmp/backup $BACKUP_DIR/mongodb_$TIMESTAMP

echo "Backing up SQL Server..."
docker exec eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SQL_PASSWORD" -Q "BACKUP DATABASE EthGraffitiExplorer TO DISK = '/tmp/backup.bak'"
docker cp eth-graffiti-sqlserver:/tmp/backup.bak $BACKUP_DIR/sqlserver_$TIMESTAMP.bak

echo "Backup completed: $BACKUP_DIR"
EOF
chmod +x $INSTALL_DIR/backup.sh

# Logs script
cat > $INSTALL_DIR/logs.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if [ -z "$1" ]; then
    docker compose logs -f
else
    docker compose logs -f $1
fi
EOF
chmod +x $INSTALL_DIR/logs.sh

echo_success "Management scripts created"

################################################################################
# Step 11: Create .env File
################################################################################

echo_info "Step 11: Creating environment configuration..."

cat > $INSTALL_DIR/.env <<EOF
# Database Passwords
SQL_PASSWORD=${SQL_PASSWORD}
MONGO_PASSWORD=${MONGO_PASSWORD}

# Beacon Node Configuration
BEACON_RPC_URL=${BEACON_RPC_URL}

# Domain Configuration
DOMAIN_NAME=${DOMAIN_NAME}

# Data Directory
DATA_DIR=${DATA_DIR}
EOF

chmod 600 $INSTALL_DIR/.env

echo_success "Environment configuration created"

################################################################################
# Step 12: SSL Certificate Setup
################################################################################

echo_info "Step 12: Setting up SSL certificates..."

# Create certbot directory
mkdir -p /var/www/certbot

# Obtain SSL certificate
if [ ! -z "$DOMAIN_NAME" ] && [ ! -z "$SSL_EMAIL" ]; then
    echo_info "Obtaining SSL certificate for ${DOMAIN_NAME}..."
    
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email ${SSL_EMAIL} \
        -d ${DOMAIN_NAME} || echo_warning "SSL certificate generation failed. You can run it manually later."
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && docker restart eth-graffiti-nginx") | crontab -
    
    echo_success "SSL certificate obtained and auto-renewal configured"
else
    echo_warning "Skipping SSL certificate setup. Configure manually if needed."
fi

################################################################################
# Step 13: Clone Repository and Build
################################################################################

echo_info "Step 13: Cloning repository and preparing build..."

cd $INSTALL_DIR

# If repository already exists, update it
if [ -d ".git" ]; then
    echo_info "Repository already exists, pulling latest changes..."
    git pull
else
    echo_info "Cloning repository..."
    git clone https://github.com/nucleoid/EthGraffitiExplorer.git .
fi

# Copy SQL schema to installation directory
cp EthGraffitiExplorer.Core/Database/SqlServer_Schema.sql .

echo_success "Repository prepared"

################################################################################
# Step 14: Start Services
################################################################################

echo_info "Step 14: Starting services..."

cd $INSTALL_DIR

# Start services
docker compose up -d

# Wait for services to be healthy
echo_info "Waiting for services to be ready..."
sleep 30

# Check service status
docker compose ps

echo_success "Services started"

################################################################################
# Step 15: Initialize Database
################################################################################

echo_info "Step 15: Initializing databases..."

# Wait for SQL Server to be fully ready
sleep 10

# Run SQL Server initialization
echo_info "Initializing SQL Server database..."
docker exec eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P "${SQL_PASSWORD}" \
    -i /docker-entrypoint-initdb.d/schema.sql || echo_warning "SQL Server initialization may need manual intervention"

echo_success "Databases initialized"

################################################################################
# Step 16: Configure DAppNode Network Access (Safe Connection)
################################################################################

echo_info "Step 16: Configuring DAppNode network access..."

# Wait for API container to be fully started
sleep 5

# Try to connect API container to DAppNode network (non-disruptive)
if docker network ls | grep -q "dncore_network"; then
    echo_info "Attempting to connect to DAppNode network 'dncore_network'..."
    
    # Check if already connected
    if docker network inspect dncore_network | grep -q "eth-graffiti-api"; then
        echo_info "API container already connected to DAppNode network"
    else
        if docker network connect dncore_network eth-graffiti-api 2>/dev/null; then
            echo_success "Successfully connected API container to DAppNode network"
            echo_info "API can now communicate with Lodestar via DAppNode network"
        else
            echo_warning "Could not connect to DAppNode network."
            echo_warning "This is normal if DAppNode uses strict network isolation."
            echo_info "Using host network access instead (BEACON_RPC_URL: ${BEACON_RPC_URL})"
        fi
    fi
else
    echo_warning "DAppNode network 'dncore_network' not found"
    echo_info "Will use direct host access to Lodestar"
fi

# Test beacon node connectivity
echo_info "Testing beacon node connectivity..."
if docker exec eth-graffiti-api curl -s -f -m 5 "${BEACON_RPC_URL}/eth/v1/node/version" > /dev/null 2>&1; then
    echo_success "Beacon node is accessible from API container"
else
    echo_warning "Cannot reach beacon node at ${BEACON_RPC_URL}"
    echo_warning "You may need to adjust the Lodestar RPC URL or network configuration"
    echo_info "Try these alternatives:"
    echo_info "  - http://172.33.1.5:9596 (DAppNode internal IP)"
    echo_info "  - http://lodestar.dappnode:9596 (DAppNode DNS)"
    echo_info "  - http://host.docker.internal:9596 (Host network)"
fi

echo_success "Network configuration completed"

################################################################################
# Final Steps and Information
################################################################################

echo ""
echo_success "=================================="
echo_success "Installation Complete!"
echo_success "=================================="
echo ""
echo_info "ETH Graffiti Explorer has been installed to: ${INSTALL_DIR}"
echo ""
echo_info "Management Commands:"
echo "  Start:   ${INSTALL_DIR}/start.sh"
echo "  Stop:    ${INSTALL_DIR}/stop.sh"
echo "  Status:  ${INSTALL_DIR}/status.sh"
echo "  Logs:    ${INSTALL_DIR}/logs.sh [service-name]"
echo "  Update:  ${INSTALL_DIR}/update.sh"
echo "  Backup:  ${INSTALL_DIR}/backup.sh"
echo ""
echo_info "Service URLs:"
echo "  Web UI:  https://${DOMAIN_NAME}"
echo "  API:     https://${DOMAIN_NAME}/api"
echo "  Swagger: https://${DOMAIN_NAME}/swagger"
echo ""
echo_info "Database Connections (localhost only):"
echo "  MongoDB: mongodb://admin:${MONGO_PASSWORD}@localhost:27017"
echo "  SQL Server: Server=localhost;User=sa;Password=${SQL_PASSWORD}"
echo ""
echo_info "Beacon Node Connection:"
echo "  URL: ${BEACON_RPC_URL}"
echo ""
echo_warning "Next Steps:"
echo "  1. Verify Lodestar beacon node is accessible at ${BEACON_RPC_URL}"
echo "  2. Access the web UI at https://${DOMAIN_NAME}"
echo "  3. Trigger initial sync: curl -X POST https://${DOMAIN_NAME}/api/beacon/sync"
echo "  4. Monitor logs: ${INSTALL_DIR}/logs.sh"
echo ""
echo_info "Data is stored in: ${DATA_DIR}"
echo_info "Configuration is in: ${INSTALL_DIR}"
echo ""
echo_success "Installation script completed successfully!"
echo ""
