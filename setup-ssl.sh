#!/bin/bash

################################################################################
# ETH Graffiti Explorer - SSL Certificate Helper
# 
# Run this script to obtain SSL certificates after installation
################################################################################

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

echo ""
echo "======================================================================"
echo "   ETH Graffiti Explorer - SSL Certificate Setup"
echo "======================================================================"
echo ""

# Get domain name
read -p "Enter your domain name: " DOMAIN_NAME
read -p "Enter your email for SSL certificates: " SSL_EMAIL

if [ -z "$DOMAIN_NAME" ] || [ -z "$SSL_EMAIL" ]; then
    echo_error "Domain name and email are required"
    exit 1
fi

# Check if certificate already exists
if [ -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ]; then
    echo_warning "Certificate already exists for ${DOMAIN_NAME}"
    read -p "Do you want to renew it? (y/N): " RENEW
    if [[ ! "$RENEW" =~ ^[Yy]$ ]]; then
        echo_info "Certificate setup cancelled"
        exit 0
    fi
fi

# Check DNS resolution
echo_info "Checking DNS resolution for ${DOMAIN_NAME}..."
SERVER_IP=$(hostname -I | awk '{print $1}')
RESOLVED_IP=$(dig +short ${DOMAIN_NAME} | tail -1)

if [ -z "$RESOLVED_IP" ]; then
    echo_error "Cannot resolve ${DOMAIN_NAME}"
    echo_info "Make sure the domain points to this server: $SERVER_IP"
    exit 1
elif [ "$RESOLVED_IP" != "$SERVER_IP" ]; then
    echo_warning "DNS points to $RESOLVED_IP but this server is $SERVER_IP"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo_success "DNS correctly points to this server"
fi

# Find container using port 80
echo_info "Checking for services using port 80..."
PORT80_CONTAINER=$(docker ps --format '{{.Names}}' | xargs -I {} sh -c 'docker port {} 2>/dev/null | grep -q "^80/tcp" && echo {}' | head -1)

if [ -z "$PORT80_CONTAINER" ]; then
    echo_warning "No container found using port 80"
    echo_info "Attempting standalone method..."
    
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email ${SSL_EMAIL} \
        -d ${DOMAIN_NAME}
    
    if [ $? -eq 0 ]; then
        echo_success "SSL certificate obtained successfully"
    else
        echo_error "Failed to obtain SSL certificate"
        exit 1
    fi
else
    echo_info "Container using port 80: $PORT80_CONTAINER"
    echo_warning "This container needs to be temporarily stopped"
    
    read -p "Stop ${PORT80_CONTAINER} to obtain certificate? (y/N): " STOP_CONTAINER
    
    if [[ "$STOP_CONTAINER" =~ ^[Yy]$ ]]; then
        echo_info "Stopping ${PORT80_CONTAINER}..."
        docker stop $PORT80_CONTAINER
        
        echo_info "Obtaining SSL certificate..."
        certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email ${SSL_EMAIL} \
            -d ${DOMAIN_NAME}
        
        if [ $? -eq 0 ]; then
            echo_success "SSL certificate obtained successfully"
        else
            echo_error "Failed to obtain SSL certificate"
        fi
        
        echo_info "Restarting ${PORT80_CONTAINER}..."
        docker start $PORT80_CONTAINER
    else
        echo_info "Trying webroot method..."
        mkdir -p /var/www/certbot
        
        certbot certonly --webroot \
            -w /var/www/certbot \
            --non-interactive \
            --agree-tos \
            --email ${SSL_EMAIL} \
            -d ${DOMAIN_NAME}
        
        if [ $? -eq 0 ]; then
            echo_success "SSL certificate obtained via webroot method"
        else
            echo_error "Webroot method failed"
            echo_info "You need to stop the service on port 80 temporarily"
            exit 1
        fi
    fi
fi

# Update nginx configuration
if [ -d "/etc/letsencrypt/live/${DOMAIN_NAME}" ]; then
    echo_info "Updating nginx configuration..."
    
    INSTALL_DIR="/opt/eth-graffiti-explorer"
    
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

    # Restart nginx
    if docker ps | grep -q "eth-graffiti-nginx"; then
        echo_info "Restarting nginx container..."
        docker restart eth-graffiti-nginx
        echo_success "Nginx restarted with new SSL configuration"
    else
        echo_warning "Nginx container not running"
        echo_info "Start it with: cd $INSTALL_DIR && docker compose up -d nginx"
    fi
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "0 3 * * * certbot renew --quiet --deploy-hook 'docker restart eth-graffiti-nginx'") | crontab -
    echo_success "Auto-renewal configured"
    
    echo ""
    echo_success "=================================="
    echo_success "SSL Certificate Setup Complete!"
    echo_success "=================================="
    echo ""
    echo_info "Your site is now accessible at:"
    echo "  https://${DOMAIN_NAME}"
    echo ""
else
    echo_error "SSL certificate not found after setup"
    exit 1
fi
