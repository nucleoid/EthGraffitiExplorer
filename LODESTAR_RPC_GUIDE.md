# Finding Your Lodestar RPC URL for DAppNode

## Quick Methods

### Method 1: Using Pre-Install Check Script
```bash
chmod +x pre-install-check.sh
sudo ./pre-install-check.sh
```
The script will automatically detect your Lodestar container and show the RPC URL.

### Method 2: Find Lodestar Container IP
```bash
# Find the Lodestar container name
docker ps | grep lodestar

# Get its IP address on DAppNode network
docker inspect <container_name> | grep -A 5 "dncore_network" | grep "IPv4Address"
```

Example output:
```
"IPv4Address": "172.33.1.5/16"
```

Your RPC URL would be: `http://172.33.1.5:9596`

### Method 3: Check DAppNode UI
1. Open DAppNode UI (usually `http://my.dappnode/`)
2. Go to **Packages** ? **Lodestar**
3. Look for **Beacon API endpoint** or **HTTP endpoint**
4. Common default: `http://lodestar.dappnode:9596`

### Method 4: Test Common Endpoints
```bash
# Test internal DAppNode DNS
curl http://lodestar.dappnode:9596/eth/v1/node/version

# Test common internal IPs
curl http://172.33.1.5:9596/eth/v1/node/version
curl http://172.33.1.6:9596/eth/v1/node/version

# Test localhost (if exposed)
curl http://localhost:9596/eth/v1/node/version
```

## Common Lodestar RPC URLs

| Scenario | URL | Notes |
|----------|-----|-------|
| DAppNode DNS | `http://lodestar.dappnode:9596` | Recommended if available |
| DAppNode IP | `http://172.33.1.5:9596` | Most common IP |
| Host Network | `http://host.docker.internal:9596` | If port forwarded |
| Localhost | `http://localhost:9596` | If bound to host |

## Verification

Once you have the URL, verify it works:

```bash
# Replace with your URL
BEACON_URL="http://172.33.1.5:9596"

# Test connection
curl -s $BEACON_URL/eth/v1/node/version | jq .

# Expected output:
# {
#   "data": {
#     "version": "Lodestar/v1.x.x/..."
#   }
# }
```

## Troubleshooting

### Error: Connection Refused
- Lodestar REST API might not be enabled
- Check DAppNode Lodestar configuration
- Enable `--rest` and `--rest-address 0.0.0.0`

### Error: Network Unreachable
- Container network not connected
- Run: `docker network connect dncore_network eth-graffiti-api`

### Error: Timeout
- Firewall blocking communication
- Check: `docker network inspect dncore_network`

## DAppNode Network Architecture

```
???????????????????????????????????????????
?         DAppNode Network                ?
?       (dncore_network)                  ?
?                                         ?
?  ????????????????  ??????????????????? ?
?  ?   Lodestar   ?  ? ETH Graffiti    ? ?
?  ? 172.33.1.5   ????  API Container  ? ?
?  ?   :9596      ?  ?                 ? ?
?  ????????????????  ??????????????????? ?
?                                         ?
???????????????????????????????????????????
```

## During Installation

When the script asks for:
```
Enter Lodestar beacon node RPC URL [http://localhost:9596]:
```

Enter one of:
- `http://lodestar.dappnode:9596` (if DAppNode DNS works)
- `http://172.33.1.5:9596` (most common)
- Press Enter to use default if Lodestar is on localhost

## After Installation

If the connection doesn't work, you can change it:

1. Edit configuration:
```bash
sudo nano /opt/eth-graffiti-explorer/.env
```

2. Update `BEACON_RPC_URL`:
```env
BEACON_RPC_URL=http://172.33.1.5:9596
```

3. Restart services:
```bash
cd /opt/eth-graffiti-explorer
sudo docker compose down
sudo docker compose up -d
```

## Security Note

The RPC URL is internal to Docker networks and not exposed to the internet. This is safe and recommended.
