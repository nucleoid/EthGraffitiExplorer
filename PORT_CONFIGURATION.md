# ETH Graffiti Explorer - Port Configuration

## Port Changes

To avoid conflicts with existing services (particularly DAppNode components), this installation uses **non-standard ports**:

| Service | Standard Port | New Port | Purpose |
|---------|--------------|----------|---------|
| HTTP | 80 | **8080** | Web access |
| HTTPS | 443 | **8443** | Secure web access |

## Accessing the Application

### Without SSL (Default)
```
Web UI:  http://your-server-ip:8080
API:     http://your-server-ip:8080/api
Swagger: http://your-server-ip:8080/swagger
```

### With SSL (If configured)
```
Web UI:  https://your-domain.com:8443
API:     https://your-domain.com:8443/api
Swagger: https://your-domain.com:8443/swagger
```

### Local Access
```
Web UI:  http://localhost:8080
API:     http://localhost:8080/api
Swagger: http://localhost:8080/swagger
```

## Internal Docker Ports

The following ports are used internally within Docker (not exposed to host):

| Service | Internal Port | Purpose |
|---------|--------------|---------|
| MongoDB | 27017 | Database (localhost only) |
| SQL Server | 1433 | Database (localhost only) |
| API | 5000 | .NET API (localhost only) |
| Web | 5001 | Blazor Web (localhost only) |
| Nginx | 80 ? 8080 | Reverse proxy |
| Nginx | 443 ? 8443 | Reverse proxy (SSL) |

## Firewall Configuration

If you enabled firewall during installation, the following rules were added:

```sh
# View firewall rules
sudo ufw status

# Ports that were opened:
# - 22/tcp   (SSH)
# - 8080/tcp (HTTP)
# - 8443/tcp (HTTPS)
```

To manually add these rules:

```sh
sudo ufw allow 22/tcp   # SSH (if not already allowed)
sudo ufw allow 8080/tcp # HTTP
sudo ufw allow 8443/tcp # HTTPS
sudo ufw enable
```

## Why Non-Standard Ports?

1. **DAppNode Compatibility**: DAppNode or other services may already be using ports 80/443
2. **Flexibility**: Easier to run alongside existing web services
3. **Security**: Non-standard ports are less targeted by automated scanners
4. **No Conflicts**: Avoids the need to stop critical services during installation

## SSL Certificate Considerations

?? **Important**: Let's Encrypt (certbot) requires port 80 for HTTP-01 challenge validation.

### SSL Setup Options

**Option 1: Use DNS Challenge (Recommended)**
```sh
sudo certbot certonly --manual --preferred-challenges dns -d your-domain.com
```
This doesn't require port 80 and works with any port configuration.

**Option 2: Temporarily Use Port 80**
If you must use HTTP-01 challenge:
```sh
# Stop service using port 80
sudo docker stop <container-using-port-80>

# Get certificate
sudo certbot certonly --standalone -d your-domain.com

# Restart service
sudo docker start <container-using-port-80>
```

**Option 3: Use Existing Reverse Proxy**
If you have nginx/apache on the host, configure it to:
- Handle SSL termination on ports 80/443
- Proxy to the application on ports 8080/8443

## Changing Back to Standard Ports

If you want to use standard ports 80/443, edit `/opt/eth-graffiti-explorer/docker-compose.yml`:

```yaml
  nginx:
    ports:
      - "80:80"      # Change from "8080:80"
      - "443:443"    # Change from "8443:443"
```

Then restart:
```sh
cd /opt/eth-graffiti-explorer
sudo docker compose down
sudo docker compose up -d
```

## Port Forwarding (For Public Access)

If you're behind a router and want external access:

1. **Router Configuration**:
   - Forward external port 80 ? internal port 8080
   - Forward external port 443 ? internal port 8443

2. **DNS Configuration**:
   - Point your domain to your public IP
   - Users access: `http://your-domain.com` (router forwards to 8080)

## Testing Connectivity

```sh
# Test local HTTP access
curl http://localhost:8080/health

# Test from another machine
curl http://your-server-ip:8080/health

# Test SSL (if configured)
curl https://your-domain.com:8443/health

# Test API
curl http://localhost:8080/api/graffiti/recent?count=5
```

## Troubleshooting

### Cannot Access via Browser

**Problem**: Browser shows "Connection Refused"

**Solution**:
```sh
# Check if nginx is running
docker ps | grep nginx

# Check if port is listening
sudo ss -tuln | grep 8080
sudo ss -tuln | grep 8443

# Check logs
cd /opt/eth-graffiti-explorer
sudo ./logs.sh nginx
```

### Port Already in Use

**Problem**: Error "port is already allocated"

**Solution**:
```sh
# Find what's using the port
sudo lsof -i :8080
sudo lsof -i :8443

# Or using ss
sudo ss -tuln | grep 8080
sudo ss -tuln | grep 8443

# Stop the conflicting service or choose different ports
```

### SSL Certificate Won't Validate

**Problem**: Certbot fails with "Connection refused"

**Cause**: Certbot needs port 80 for HTTP-01 challenge

**Solution**: Use DNS challenge instead:
```sh
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  --email your-email@example.com \
  -d your-domain.com
```

## Network Security

### Exposed Ports
- **8080** (HTTP) - Publicly accessible
- **8443** (HTTPS) - Publicly accessible

### Internal Ports (Not Exposed)
- **27017** (MongoDB) - Only localhost
- **1433** (SQL Server) - Only localhost
- **5000** (API) - Only Docker network
- **5001** (Web) - Only Docker network

### Best Practices

1. **Enable UFW**: 
```sh
sudo ufw enable
sudo ufw status
```

2. **Limit Access**: Consider restricting access by IP if possible:
```sh
sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp
```

3. **Use SSL**: Always enable HTTPS for production:
```sh
cd /opt/eth-graffiti-explorer
# Edit docker-compose.yml to enable SSL configuration
sudo docker compose restart nginx
```

4. **Monitor Logs**: Regularly check for suspicious activity:
```sh
cd /opt/eth-graffiti-explorer
sudo ./logs.sh nginx | grep -E "(404|403|500)"
```

## Summary

? **HTTP**: Port 8080 (instead of 80)  
? **HTTPS**: Port 8443 (instead of 443)  
? **Databases**: Localhost only (not exposed)  
? **DAppNode**: No port conflicts  
? **Firewall**: Configure for ports 8080/8443  
? **SSL**: Use DNS challenge or temporarily free port 80  

For questions or issues, check the logs:
```sh
cd /opt/eth-graffiti-explorer
sudo ./logs.sh
```
