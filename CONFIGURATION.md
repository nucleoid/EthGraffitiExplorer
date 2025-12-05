# ETH Graffiti Explorer - Configuration Guide

## Architecture Overview

This solution uses a **hybrid database architecture** for optimal performance:

- **MongoDB** - NoSQL storage for graffiti data (high-volume, flexible schema)
- **SQL Server with Dapper** - Relational storage for validators and beacon blocks (structured data)

## API Configuration

### appsettings.json

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=EthGraffitiExplorer;Trusted_Connection=true;MultipleActiveResultSets=true"
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

### Database Options

#### MongoDB Configuration (Required for Graffiti Storage)

**Local MongoDB:**
```json
"MongoDB": {
  "ConnectionString": "mongodb://localhost:27017",
  "DatabaseName": "EthGraffitiExplorer",
  "GraffitiCollectionName": "graffiti"
}
```

**MongoDB Atlas (Cloud):**
```json
"MongoDB": {
  "ConnectionString": "mongodb+srv://username:password@cluster.mongodb.net/?retryWrites=true&w=majority",
  "DatabaseName": "EthGraffitiExplorer",
  "GraffitiCollectionName": "graffiti"
}
```

**MongoDB with Authentication:**
```json
"MongoDB": {
  "ConnectionString": "mongodb://username:password@localhost:27017/EthGraffitiExplorer?authSource=admin",
  "DatabaseName": "EthGraffitiExplorer",
  "GraffitiCollectionName": "graffiti"
}
```

#### SQL Server Configuration (For Validators and Blocks)

**SQL Server LocalDB (Development):**
```json
"DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=EthGraffitiExplorer;Trusted_Connection=true;MultipleActiveResultSets=true"
```

**SQL Server (Production):**
```json
"DefaultConnection": "Server=your-server;Database=EthGraffitiExplorer;User Id=your-user;Password=your-password;TrustServerCertificate=true"
```

**Azure SQL Database:**
```json
"DefaultConnection": "Server=tcp:your-server.database.windows.net,1433;Initial Catalog=EthGraffitiExplorer;Persist Security Info=False;User ID=your-user;Password=your-password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```

## Beacon Node Configuration

### Lighthouse
```json
{
  "BeaconNode": {
    "Url": "http://localhost:5052"
  }
}
```

### Prysm
```json
{
  "BeaconNode": {
    "Url": "http://localhost:3500"
  }
}
```

### Teku
```json
{
  "BeaconNode": {
    "Url": "http://localhost:5051"
  }
}
```

### Remote Node
```json
{
  "BeaconNode": {
    "Url": "https://your-beacon-node.example.com"
  }
}
```

## Web App Configuration

### appsettings.json

```json
{
  "ApiSettings": {
    "BaseUrl": "https://localhost:7001"
  }
}
```

Update `BaseUrl` to point to your deployed API.

## Mobile App Configuration

### MauiProgram.cs

```csharp
var apiBaseUrl = "https://your-api-url.com";
builder.Services.AddHttpClient<GraffitiApiService>(client =>
{
    client.BaseAddress = new Uri(apiBaseUrl);
});
```

### Android Network Security

For Android, if using HTTP (not recommended for production), add to `Platforms/Android/Resources/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">your-api-domain.com</domain>
    </domain-config>
</network-security-config>
```

### iOS App Transport Security

For iOS, if using HTTP, add to `Platforms/iOS/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Database Setup

### MongoDB Setup

#### Install MongoDB

**Windows:**
Download and install from [MongoDB Download Center](https://www.mongodb.com/try/download/community)

**macOS (Homebrew):**
```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

**Linux (Ubuntu):**
```bash
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -sc)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
```

**Docker:**
```bash
docker run -d -p 27017:27017 --name mongodb mongo:latest
```

#### Verify MongoDB Connection
```bash
mongosh
# or for older versions
mongo
```

MongoDB indexes will be created automatically on first startup.

### SQL Server Setup

#### Create SQL Database

Run the SQL schema script:
```bash
cd EthGraffitiExplorer.Core/Database
sqlcmd -S (localdb)\mssqllocaldb -i SqlServer_Schema.sql
```

Or manually execute `SqlServer_Schema.sql` in SQL Server Management Studio.

#### Using Entity Framework Migrations (Optional)

If you prefer EF Core migrations:
```bash
cd EthGraffitiExplorer.Api
dotnet ef migrations add InitialCreate --project ../EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj
dotnet ef database update --project ../EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj
```

## CORS Configuration

By default, the API allows all origins. For production, restrict CORS in `Program.cs`:

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("Production", policy =>
    {
        policy.WithOrigins("https://your-web-app.com", "https://your-mobile-app.com")
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Then use it:
app.UseCors("Production");
```

## Logging Configuration

### Development
Set in `appsettings.Development.json`:
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information",
      "Microsoft.EntityFrameworkCore": "Information"
    }
  }
}
```

### Production
Set in `appsettings.json`:
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  }
}
```

## Performance Tuning

### MongoDB Indexing
MongoDB indexes are created automatically on startup:
- **Slot** - Ascending index for chronological queries
- **ValidatorIndex** - For validator-specific queries
- **BlockHash** - Unique index for deduplication
- **Timestamp** - Descending index for recent data
- **DecodedGraffiti** - Text index for full-text search
- **Compound Index** - ValidatorIndex + Timestamp

### SQL Server with Dapper
Dapper provides near-optimal performance for SQL queries:
- Raw SQL queries with minimal overhead
- Efficient mapping to POCOs
- No change tracking overhead

Connection pooling is enabled by default:
```json
"DefaultConnection": "Server=...;Pooling=true;Min Pool Size=5;Max Pool Size=100"
```

### MongoDB Performance Tips

**Connection String Options:**
```json
"ConnectionString": "mongodb://localhost:27017/?maxPoolSize=50&minPoolSize=10&retryWrites=true"
```

**Read Preference for Replicas:**
```json
"ConnectionString": "mongodb://localhost:27017/?readPreference=secondaryPreferred"
```

### Caching
Consider adding response caching for frequently accessed data:

```csharp
builder.Services.AddResponseCaching();
app.UseResponseCaching();
```

### Why Dapper + MongoDB?

**Dapper Benefits:**
- ?? Near-native SQL performance (98% of raw ADO.NET speed)
- ?? Full control over SQL queries
- ?? Simple, lightweight ORM
- ? Perfect for structured, relational data

**MongoDB Benefits:**
- ?? Horizontal scaling for high-volume graffiti data
- ?? Powerful full-text search capabilities
- ?? Aggregation pipelines for analytics
- ?? Flexible schema for graffiti metadata
- ? Fast writes for real-time ingestion

## Security Recommendations

1. **HTTPS Only** - Always use HTTPS in production
2. **API Keys** - Add API key authentication for mobile apps
3. **Rate Limiting** - Implement rate limiting to prevent abuse
4. **SQL Injection** - Already protected via EF Core parameterization
5. **CORS** - Restrict to known origins in production
6. **Secrets** - Use Azure Key Vault or similar for production secrets

## Deployment

### API Deployment
- Azure App Service
- Docker container
- IIS on Windows Server
- Nginx reverse proxy on Linux

### Web App Deployment
- Azure Static Web Apps
- Azure App Service
- Docker container

### Database Deployment
- Azure SQL Database
- AWS RDS
- Self-hosted SQL Server

## Monitoring

Add Application Insights for monitoring:

```bash
dotnet add package Microsoft.ApplicationInsights.AspNetCore
```

```csharp
builder.Services.AddApplicationInsightsTelemetry();
```
