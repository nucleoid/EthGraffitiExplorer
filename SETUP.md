# ETH Graffiti Explorer - Setup Guide

## Quick Start

### Prerequisites
- .NET 8 SDK or later
- MongoDB 6.0+ (local or cloud)
- SQL Server (LocalDB for development, or full instance)
- Ethereum Beacon Chain Node (Lighthouse, Prysm, Teku, etc.)

### 1. Install MongoDB

Choose one option:

**Option A: Local Installation**
- Windows: Download from [mongodb.com](https://www.mongodb.com/try/download/community)
- macOS: `brew install mongodb-community`
- Linux: Follow [official guide](https://www.mongodb.com/docs/manual/installation/)

**Option B: Docker**
```bash
docker run -d -p 27017:27017 --name mongodb \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  mongo:latest
```

**Option C: MongoDB Atlas (Cloud)**
- Create free cluster at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas)
- Get connection string from Atlas dashboard

### 2. Setup SQL Server

**For Development (LocalDB):**
```bash
# Verify LocalDB is installed
sqllocaldb info

# Create database using provided script
cd EthGraffitiExplorer.Core/Database
sqlcmd -S (localdb)\mssqllocaldb -i SqlServer_Schema.sql
```

**For Production:**
Use SQL Server Management Studio or Azure SQL Database

### 3. Configure Application

Edit `appsettings.json` in the API project:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=EthGraffitiExplorer;Trusted_Connection=true"
  },
  "MongoDB": {
    "ConnectionString": "mongodb://localhost:27017",
    "DatabaseName": "EthGraffitiExplorer",
    "GraffitiCollectionName": "graffiti"
  },
  "BeaconNode": {
    "Url": "http://localhost:5052"
  }
}
```

### 4. Restore NuGet Packages

```bash
cd EthGraffitiExplorer.Api
dotnet restore
```

### 5. Run the API

```bash
cd EthGraffitiExplorer.Api
dotnet run
```

API will be available at `https://localhost:7001`

### 6. Sync Graffiti Data

Once the API is running, trigger data synchronization:

```bash
curl -X POST https://localhost:7001/api/beacon/sync
```

Or use Swagger UI at `https://localhost:7001/swagger`

### 7. Run Web Interface

In a new terminal:

```bash
cd EthGraffitiExplorer.Web
dotnet run
```

Web app will be available at `https://localhost:5001`

### 8. Run Mobile App (Optional)

```bash
# Install MAUI workload first
dotnet workload install maui

cd EthGraffitiExplorer.Mobile

# Android
dotnet build -t:Run -f net9.0-android

# iOS (macOS only)
dotnet build -t:Run -f net9.0-ios

# Windows
dotnet build -t:Run -f net9.0-windows10.0.19041.0
```

## Architecture Overview

### Data Flow

```
Beacon Node ??> API ?????> MongoDB (Graffiti)
                      ?
                      ???> SQL Server (Validators/Blocks)
                             ?
                          Dapper
                             ?
                         Web/Mobile Apps
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Graffiti Storage | MongoDB | High-volume, flexible NoSQL storage |
| Relational Data | SQL Server + Dapper | Structured validator/block data |
| API | ASP.NET Core 8 | RESTful backend service |
| Web UI | Blazor Server | Modern C# web interface |
| Mobile | .NET MAUI | Cross-platform native apps |
| ETH Integration | Nethereum | Beacon chain communication |

## Hybrid Database Architecture Benefits

### MongoDB for Graffiti
- ? **Scalability**: Horizontal scaling for growing data
- ? **Performance**: Fast writes for real-time ingestion
- ? **Flexibility**: Schema-less for metadata variations
- ? **Search**: Built-in full-text search
- ? **Analytics**: Powerful aggregation pipelines

### SQL Server + Dapper for Relational Data
- ? **ACID Compliance**: Guaranteed data integrity
- ? **Performance**: Dapper's near-native speed
- ? **Control**: Full SQL query control
- ? **Simplicity**: Lightweight, minimal overhead

## Configuration Examples

### Development (Local)

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=EthGraffitiExplorer;Trusted_Connection=true"
  },
  "MongoDB": {
    "ConnectionString": "mongodb://localhost:27017",
    "DatabaseName": "EthGraffitiExplorer_Dev"
  },
  "BeaconNode": {
    "Url": "http://localhost:5052"
  }
}
```

### Production (Cloud)

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:yourserver.database.windows.net,1433;Database=EthGraffitiExplorer;User ID=admin;Password=YourPassword123!;Encrypt=True;"
  },
  "MongoDB": {
    "ConnectionString": "mongodb+srv://admin:password@cluster.mongodb.net/?retryWrites=true&w=majority",
    "DatabaseName": "EthGraffitiExplorer_Prod"
  },
  "BeaconNode": {
    "Url": "https://your-beacon-node.com"
  }
}
```

### Docker Compose Setup

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  mongodb:
    image: mongo:latest
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password
    volumes:
      - mongodb_data:/data/db

  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    ports:
      - "1433:1433"
    environment:
      ACCEPT_EULA: Y
      SA_PASSWORD: YourPassword123!
    volumes:
      - sqlserver_data:/var/opt/mssql

  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "7001:80"
    environment:
      ConnectionStrings__DefaultConnection: "Server=sqlserver;Database=EthGraffitiExplorer;User=sa;Password=YourPassword123!;TrustServerCertificate=true"
      MongoDB__ConnectionString: "mongodb://admin:password@mongodb:27017"
      BeaconNode__Url: "http://your-beacon-node:5052"
    depends_on:
      - mongodb
      - sqlserver

volumes:
  mongodb_data:
  sqlserver_data:
```

Run with:
```bash
docker-compose up -d
```

## Verification Steps

### 1. Check MongoDB Connection

```bash
mongosh
use EthGraffitiExplorer
db.graffiti.countDocuments()
```

### 2. Check SQL Server Connection

```bash
sqlcmd -S localhost -U sa -P YourPassword
SELECT COUNT(*) FROM Validators;
SELECT COUNT(*) FROM BeaconBlocks;
GO
```

### 3. Test API Health

```bash
curl https://localhost:7001/api/beacon/health
```

### 4. View Recent Graffiti

```bash
curl https://localhost:7001/api/graffiti/recent?count=10
```

## Troubleshooting

### MongoDB Connection Issues

**Error: "MongoServerSelectionTimeoutException"**
- Verify MongoDB is running: `systemctl status mongod` (Linux) or check Services (Windows)
- Check connection string format
- Ensure port 27017 is not blocked

### SQL Server Connection Issues

**Error: "Cannot connect to SQL Server"**
- Verify SQL Server is running
- Check connection string credentials
- Enable TCP/IP in SQL Server Configuration Manager

### Beacon Node Connection Issues

**Error: "Failed to connect to beacon node"**
- Verify beacon node is synced and running
- Check beacon node REST API port (typically 5052 for Lighthouse)
- Ensure `--http` flag is enabled on beacon node

## Performance Optimization

### MongoDB Indexes

Indexes are created automatically, but you can verify:

```javascript
use EthGraffitiExplorer
db.graffiti.getIndexes()
```

### SQL Server Indexes

Check index usage:

```sql
SELECT * FROM sys.dm_db_index_usage_stats 
WHERE database_id = DB_ID('EthGraffitiExplorer');
```

### Monitoring

Add Application Insights (optional):

```bash
dotnet add package Microsoft.ApplicationInsights.AspNetCore
```

In `Program.cs`:
```csharp
builder.Services.AddApplicationInsightsTelemetry();
```

## Security Checklist

- [ ] Change default MongoDB credentials
- [ ] Use strong SQL Server passwords
- [ ] Enable HTTPS/TLS for MongoDB
- [ ] Restrict CORS to known origins
- [ ] Use environment variables for secrets
- [ ] Enable authentication on MongoDB
- [ ] Use Azure Key Vault for production secrets
- [ ] Implement rate limiting on API
- [ ] Enable SQL Server encryption
- [ ] Use firewall rules for database access

## Next Steps

1. Configure your beacon node connection
2. Run initial data sync
3. Explore the Swagger UI at `/swagger`
4. Customize the Web UI
5. Deploy to production
6. Set up monitoring and alerts

## Support

For issues or questions:
- Check the README.md for architecture details
- Review CONFIGURATION.md for advanced settings
- Open an issue on GitHub
- Check MongoDB and SQL Server logs

## License

MIT License - See LICENSE file for details
