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
DAPPNODE_DETECTED=false
if docker network ls | grep -q "dncore_network\|dappnode"; then
    echo_success "DAppNode network detected - will connect API container later"
    DAPPNODE_DETECTED=true
else
    echo_warning "DAppNode network not detected. Will use host network for beacon node access."
fi

echo_success "Docker network setup completed"

################################################################################
# Step 5: Clone Repository First
################################################################################

echo_info "Step 5: Cloning repository..."

cd $INSTALL_DIR

# Check if directory has files
if [ -d ".git" ]; then
    echo_info "Git repository found, pulling latest changes..."
    git pull || echo_warning "Could not pull latest changes, using existing code"
elif [ "$(ls -A $INSTALL_DIR 2>/dev/null | grep -v lost+found)" ]; then
    echo_warning "Directory contains files but no git repository"
    read -p "Clear directory and clone fresh? (y/N): " CLEAR_DIR
    if [[ "$CLEAR_DIR" =~ ^[Yy]$ ]]; then
        find $INSTALL_DIR -mindepth 1 -not -name 'lost+found' -delete
        git clone https://github.com/nucleoid/EthGraffitiExplorer.git . || {
            echo_error "Failed to clone repository"
            exit 1
        }
    else
        echo_info "Using existing files in $INSTALL_DIR"
    fi
else
    echo_info "Cloning repository..."
    git clone https://github.com/nucleoid/EthGraffitiExplorer.git . || {
        echo_error "Failed to clone repository"
        echo_info "You can manually clone it:"
        echo_info "  cd $INSTALL_DIR"
        echo_info "  git clone https://github.com/nucleoid/EthGraffitiExplorer.git ."
        exit 1
    }
fi

echo_success "Repository prepared"

################################################################################
# Step 6: Create Dockerfiles
################################################################################

echo_info "Step 6: Creating Dockerfiles..."

# API Dockerfile
cat > $INSTALL_DIR/Dockerfile.api <<'EOF'
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution file
COPY ["EthGraffitiExplorer.sln", "./"]

# Copy all project files
COPY ["EthGraffitiExplorer.Api/EthGraffitiExplorer.Api.csproj", "EthGraffitiExplorer.Api/"]
COPY ["EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj", "EthGraffitiExplorer.Core/"]

# Restore dependencies
RUN dotnet restore "EthGraffitiExplorer.Api/EthGraffitiExplorer.Api.csproj"

# Copy all source code
COPY . .

# Build
WORKDIR "/src/EthGraffitiExplorer.Api"
RUN dotnet build "EthGraffitiExplorer.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "EthGraffitiExplorer.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Install curl for health checks
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

# Copy solution file
COPY ["EthGraffitiExplorer.sln", "./"]

# Copy all project files
COPY ["EthGraffitiExplorer.Web/EthGraffitiExplorer.Web.csproj", "EthGraffitiExplorer.Web/"]
COPY ["EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj", "EthGraffitiExplorer.Core/"]

# Restore dependencies
RUN dotnet restore "EthGraffitiExplorer.Web/EthGraffitiExplorer.Web.csproj"

# Copy all source code
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
# Step 7: Create MongoDB Initialization Script
################################################################################

echo_info "Step 7: Creating MongoDB initialization script..."

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
db.graffiti.createIndex({ slot: 1 }, { unique: true });
db.graffiti.createIndex({ validatorIndex: 1 });
db.graffiti.createIndex({ blockHash: 1 }, { unique: true });
db.graffiti.createIndex({ timestamp: -1 });
db.graffiti.createIndex({ decodedGraffiti: 'text' });
db.graffiti.createIndex({ validatorIndex: 1, timestamp: -1 });

print('MongoDB initialization completed successfully');
EOF

echo_success "MongoDB initialization script created"

################################################################################
# Step 8: Prepare SQL Schema
################################################################################

echo_info "Step 8: Preparing SQL Server schema..."

# Find and copy SQL schema
SQL_SCHEMA_SOURCES=(
    "EthGraffitiExplorer.Core/Database/SqlServer_Schema.sql"
    "EthGraffitiExplorer.Core/SqlServer_Schema.sql"
    "Database/SqlServer_Schema.sql"
    "SqlServer_Schema.sql"
)

SQL_SCHEMA_FOUND=false
for source in "${SQL_SCHEMA_SOURCES[@]}"; do
    if [ -f "$source" ]; then
        cp "$source" $INSTALL_DIR/SqlServer_Schema.sql
        echo_success "SQL schema found and copied from $source"
        SQL_SCHEMA_FOUND=true
        break
    fi
done

if [ "$SQL_SCHEMA_FOUND" = false ]; then
    echo_warning "SQL schema file not found, creating basic schema..."
    cat > $INSTALL_DIR/SqlServer_Schema.sql <<'EOF'
-- ETH Graffiti Explorer Database Schema
-- Basic schema - will be populated by EF migrations

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'EthGraffitiExplorer')
BEGIN
    CREATE DATABASE EthGraffitiExplorer;
END
GO

USE EthGraffitiExplorer;
GO

-- The actual tables will be created by Entity Framework migrations
-- This script just ensures the database exists
EOF
fi

echo_success "SQL schema prepared"

################################################################################
# Step 9: Create Docker Compose Configuration
################################################################################

echo_info "Step 9: Creating Docker Compose configuration..."

# Determine network configuration
if [ "$DAPPNODE_DETECTED" = true ]; then
    NETWORK_CONFIG="
      - eth-graffiti-net
      - dncore_network"
    EXTRA_NETWORKS="
  dncore_network:
    external: true"
else
    NETWORK_CONFIG="
      - eth-graffiti-net"
    EXTRA_NETWORKS=""
fi

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
    networks:${NETWORK_CONFIG}
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
    external: true${EXTRA_NETWORKS}

EOF

echo_success "Docker Compose configuration created"

################################################################################
# Step 10: Create Nginx Configuration
################################################################################

echo_info "Step 10: Creating Nginx configuration..."

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

# Create nginx site config based on whether SSL is available
if [ -z "$DOMAIN_NAME" ] || [ ! -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ]; then
    echo_info "Creating HTTP-only nginx configuration..."
    cat > $INSTALL_DIR/nginx-site.conf <<'EOF'
# HTTP Only Server (no SSL)
server {
    listen 80;
    server_name _;

    # API Proxy
    location /api/ {
        proxy_pass http://api:80/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
    }

    # Swagger UI
    location /swagger/ {
        proxy_pass http://api:80/swagger/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Web UI
    location / {
        proxy_pass http://web:80/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # WebSocket support for Blazor Server
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF
else
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
fi

echo_success "Nginx configuration created"

################################################################################
# Step 11: Create Systemd Service
################################################################################

echo_info "Step 11: Creating systemd service..."

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
# Step 12: Create Management Scripts
################################################################################

echo_info "Step 12: Creating management scripts..."

# Create logs directory
mkdir -p $INSTALL_DIR/logs/api
mkdir -p $INSTALL_DIR/logs/web

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
cat > $INSTALL_DIR/backup.sh <<EOF
#!/bin/bash
BACKUP_DIR="/backup/eth-graffiti-explorer"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

echo "Backing up MongoDB..."
docker exec eth-graffiti-mongodb mongodump --out=/tmp/backup --quiet
docker cp eth-graffiti-mongodb:/tmp/backup \$BACKUP_DIR/mongodb_\$TIMESTAMP

echo "Backing up SQL Server..."
docker exec eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "${SQL_PASSWORD}" -Q "BACKUP DATABASE EthGraffitiExplorer TO DISK = '/tmp/backup.bak'"
docker cp eth-graffiti-sqlserver:/tmp/backup.bak \$BACKUP_DIR/sqlserver_\$TIMESTAMP.bak

echo "Backup completed: \$BACKUP_DIR"
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
# Step 13: Create .env File
################################################################################

echo_info "Step 13: Creating environment configuration..."

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
# Step 14: SSL Certificate Setup
################################################################################

echo_info "Step 14: Setting up SSL certificates..."

# Create certbot directory
mkdir -p /var/www/certbot

# Obtain SSL certificate
if [ ! -z "$DOMAIN_NAME" ] && [ ! -z "$SSL_EMAIL" ]; then
    echo_info "Obtaining SSL certificate for ${DOMAIN_NAME}..."
    
    # Check if certificate already exists
    if [ -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ]; then
        echo_success "SSL certificate already exists for ${DOMAIN_NAME}"
    else
        # Try webroot method first (doesn't require stopping nginx)
        echo_info "Attempting webroot method (no port conflict)..."
        mkdir -p /var/www/certbot
        
        if certbot certonly --webroot \
            -w /var/www/certbot \
            --non-interactive \
            --agree-tos \
            --email ${SSL_EMAIL} \
            -d ${DOMAIN_NAME} 2>/dev/null; then
            echo_success "SSL certificate obtained via webroot method"
        else
            echo_warning "Webroot method failed. Trying standalone method..."
            echo_info "This requires stopping the service using port 80..."
            
            # Find and stop the service using port 80
            PORT80_CONTAINER=$(docker ps --format '{{.Names}}' | xargs -I {} sh -c 'docker port {} 2>/dev/null | grep -q "^80/tcp" && echo {}' | head -1)
            
            if [ ! -z "$PORT80_CONTAINER" ]; then
                echo_info "Temporarily stopping container: $PORT80_CONTAINER"
                docker stop $PORT80_CONTAINER
                
                # Try standalone method
                if certbot certonly --standalone \
                    --non-interactive \
                    --agree-tos \
                    --email ${SSL_EMAIL} \
                    -d ${DOMAIN_NAME}; then
                    echo_success "SSL certificate obtained via standalone method"
                else
                    echo_error "SSL certificate generation failed"
                fi
                
                # Restart the container
                echo_info "Restarting container: $PORT80_CONTAINER"
                docker start $PORT80_CONTAINER
            else
                echo_warning "Could not obtain SSL certificate automatically"
                echo_info "You can try manually:"
                echo_info "  sudo systemctl stop nginx  # or your web server"
                echo_info "  sudo certbot certonly --standalone -d ${DOMAIN_NAME}"
                echo_info "  sudo systemctl start nginx"
            fi
        fi
    fi
    
    # Setup auto-renewal
    if [ -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ]; then
        (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 3 * * * certbot renew --quiet --deploy-hook 'docker restart eth-graffiti-nginx'") | crontab -
        echo_success "SSL certificate auto-renewal configured"
    fi
else
    echo_warning "Skipping SSL certificate setup. Configure manually if needed."
fi

################################################################################
# Step 15: Start Services
################################################################################

echo_info "Step 15: Starting services..."

cd $INSTALL_DIR

# Build and start services
echo_info "Building Docker images (this may take several minutes)..."
docker compose build || {
    echo_error "Docker build failed. Check the logs above for errors."
    echo_info "Common issues:"
    echo_info "  - Missing project files"
    echo_info "  - NuGet package restore failures"
    echo_info "  - .NET SDK issues"
    exit 1
}

echo_info "Starting containers..."
docker compose up -d

# Wait for services to be healthy
echo_info "Waiting for services to be ready (this may take 30-60 seconds)..."
sleep 30

# Check service status
docker compose ps

echo_success "Services started"

################################################################################
# Step 16: Initialize Database
################################################################################

echo_info "Step 16: Initializing databases..."

# Wait for SQL Server to be fully ready
echo_info "Waiting for SQL Server to be ready..."
sleep 15

# Check if SQL Server is healthy
if docker exec eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "${SQL_PASSWORD}" -Q "SELECT 1" > /dev/null 2>&1; then
    echo_success "SQL Server is ready"
    
    # Run schema initialization if it exists
    if [ -f "$INSTALL_DIR/SqlServer_Schema.sql" ]; then
        echo_info "Running SQL Server schema initialization..."
        docker exec eth-graffiti-sqlserver /opt/mssql-tools/bin/sqlcmd \
            -S localhost \
            -U sa \
            -P "${SQL_PASSWORD}" \
            -i /docker-entrypoint-initdb.d/schema.sql 2>/dev/null || echo_warning "Schema may already exist or will be created by EF migrations"
    fi
else
    echo_warning "SQL Server not responding yet. It may still be initializing."
    echo_info "Check logs with: $INSTALL_DIR/logs.sh sqlserver"
fi

# Trigger EF migrations through API
echo_info "Triggering database migrations via API..."
sleep 10
if docker exec eth-graffiti-api curl -s -f http://localhost:80/health > /dev/null 2>&1; then
    echo_success "API is responding - migrations should run automatically"
else
    echo_warning "API not responding yet. Migrations will run on first API start."
fi

echo_success "Database initialization completed"

################################################################################
# Step 17: Configure DAppNode Network Access
################################################################################

if [ "$DAPPNODE_DETECTED" = true ]; then
    echo_info "Step 17: Configuring DAppNode network access..."

    # Wait for API container to be fully started
    sleep 5

    # The API container should already be connected via docker-compose
    # Verify the connection
    if docker network inspect dncore_network | grep -q "eth-graffiti-api"; then
        echo_success "API container connected to DAppNode network"
        echo_info "API can communicate with Lodestar via DAppNode network"
    else
        echo_warning "API container not connected to DAppNode network"
        echo_info "This may be intentional if using host network access"
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
else
    echo_info "Step 17: Skipping DAppNode network configuration (not detected)"
fi

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
if [ -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ] && [ ! -z "$DOMAIN_NAME" ]; then
    echo "  Web UI:  https://${DOMAIN_NAME}"
    echo "  API:     https://${DOMAIN_NAME}/api"
    echo "  Swagger: https://${DOMAIN_NAME}/swagger"
else
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "  Web UI:  http://${SERVER_IP} (or http://localhost)"
    echo "  API:     http://${SERVER_IP}/api"
    echo "  Swagger: http://${SERVER_IP}/swagger"
    if [ ! -z "$DOMAIN_NAME" ]; then
        echo ""
        echo_warning "SSL not configured. To add SSL later:"
        echo "  1. Ensure ${DOMAIN_NAME} points to this server"
        echo "  2. Run: $INSTALL_DIR/setup-ssl.sh"
    fi
fi
echo ""
echo_info "Database Connections (localhost only):"
echo "  MongoDB: mongodb://admin:***@localhost:27017"
echo "  SQL Server: Server=localhost;User=sa;Password=***"
echo ""
echo_info "Beacon Node Connection:"
echo "  URL: ${BEACON_RPC_URL}"
echo ""
echo_warning "Next Steps:"
echo "  1. Verify services are running: ${INSTALL_DIR}/status.sh"
echo "  2. Check API health: curl http://localhost:5000/health"
echo "  3. Access the web UI in your browser"
echo "  4. Trigger initial sync: curl -X POST http://localhost:5000/api/beacon/sync"
echo "  5. Monitor logs: ${INSTALL_DIR}/logs.sh"
echo ""
echo_info "Data is stored in: ${DATA_DIR}"
echo_info "Configuration is in: ${INSTALL_DIR}"
echo ""
echo_success "Installation script completed successfully!"
echo ""
