# ETH Graffiti Explorer

A comprehensive solution for exploring Ethereum validator graffiti messages from your local beacon chain node.

## Architecture

This solution consists of 4 projects:

### 1. EthGraffitiExplorer.Core (.NET 8 Class Library)
Shared business logic and data models used across all projects.

**Features:**
- Data models: `ValidatorGraffiti`, `Validator`, `BeaconBlock`
- DTOs for API responses
- Repository interfaces for data access
- Entity Framework Core database context
- Beacon Chain API integration service
- Graffiti decoding logic for non-printable characters

**Key NuGet Packages:**
- Nethereum.Web3 (4.19.0) - Ethereum integration
- Microsoft.EntityFrameworkCore.SqlServer (8.0.0)

### 2. EthGraffitiExplorer.Api (.NET 8 ASP.NET Core Web API)
RESTful API backend service.

**Endpoints:**
- `GET /api/graffiti/recent` - Get recent graffiti
- `POST /api/graffiti/search` - Search with filters
- `GET /api/graffiti/{id}` - Get graffiti by ID
- `GET /api/graffiti/validator/{validatorIndex}` - Get validator's graffiti
- `GET /api/graffiti/top` - Get most common graffiti
- `GET /api/validators/{validatorIndex}` - Get validator details
- `GET /api/beacon/current-slot` - Get current beacon chain slot
- `POST /api/beacon/sync` - Sync blocks from beacon node

**Features:**
- Swagger/OpenAPI documentation
- CORS enabled for cross-origin requests
- SQL Server database with Entity Framework Core
- Repository pattern for data access

### 3. EthGraffitiExplorer.Web (.NET 8 Blazor Server)
Modern web interface using Blazor Server (C# only, no JavaScript required).

**Pages:**
- Home dashboard with recent graffiti and statistics
- Graffiti list with search and filtering
- Graffiti detail view
- Validator detail view

**Features:**
- Server-side rendering for fast load times
- Real-time updates
- Responsive design with Bootstrap

### 4. EthGraffitiExplorer.Mobile (.NET 9 MAUI)
Cross-platform mobile app for iOS, Android, Windows, and macOS.

**Pages:**
- Graffiti list with search
- Graffiti details
- Validator details

**Features:**
- Native UI performance
- Works on iOS, Android, Windows, macOS
- Offline-capable design

## Getting Started

### Quick Deploy on Debian Server with DAppNode (Recommended) ??

**Run this on your validator server - completely safe alongside DAppNode!**

```bash
# Download and run setup
wget https://raw.githubusercontent.com/nucleoid/EthGraffitiExplorer/main/setup.sh
chmod +x setup.sh && ./setup.sh

# Run pre-check (finds your Lodestar RPC URL automatically)
sudo ./pre-install-check.sh

# Install (won't touch Docker/DAppNode/Validator)
sudo ./install-debian.sh
```

**See [DEPLOYMENT_DEBIAN.md](DEPLOYMENT_DEBIAN.md) for complete guide.**  
**See [DAPPNODE_COMPATIBILITY.md](DAPPNODE_COMPATIBILITY.md) for safety details.**

### Local Development

#### Prerequisites
- .NET 8 SDK or later
- MongoDB 6.0+ (Docker or local install)
- SQL Server or SQL Server LocalDB
- Ethereum Beacon Chain Node (e.g., Lighthouse, Lodestar, Prysm, Teku)

### Configuration

#### 1. Configure Database Connection
Update `appsettings.json` in **EthGraffitiExplorer.Api**:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=EthGraffitiExplorer;Trusted_Connection=true;MultipleActiveResultSets=true"
  }
}
```

For production, use a proper SQL Server connection string.

#### 2. Configure Beacon Node
Update `appsettings.json` in **EthGraffitiExplorer.Api**:

```json
{
  "BeaconNode": {
    "Url": "http://localhost:5052"
  }
}
```

Replace with your beacon node's REST API URL.

#### 3. Create Database
Run migrations from the API project directory:

```bash
cd EthGraffitiExplorer.Api
dotnet ef database update --project ../EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj
```

### Running the Solution

#### 1. Start the API
```bash
cd EthGraffitiExplorer.Api
dotnet run
```

API will be available at `https://localhost:7001` (or as configured).

#### 2. Sync Graffiti Data
Call the sync endpoint to start importing graffiti:

```bash
curl -X POST https://localhost:7001/api/beacon/sync
```

#### 3. Run the Web App
In a new terminal:

```bash
cd EthGraffitiExplorer.Web
dotnet run
```

Update `appsettings.json` to point to your API URL:

```json
{
  "ApiSettings": {
    "BaseUrl": "https://localhost:7001"
  }
}
```

#### 4. Run the Mobile App
```bash
cd EthGraffitiExplorer.Mobile
dotnet build -t:Run -f net9.0-android
```

For iOS:
```bash
dotnet build -t:Run -f net9.0-ios
```

For Windows:
```bash
dotnet build -t:Run -f net9.0-windows10.0.19041.0
```

Update `MauiProgram.cs` with your API URL.

## Database Schema

### ValidatorGraffiti
- `Id` - Primary key
- `Slot` - Beacon chain slot number (indexed)
- `Epoch` - Epoch number
- `BlockNumber` - Block number
- `BlockHash` - Block hash (indexed)
- `ValidatorIndex` - Validator index (indexed)
- `RawGraffiti` - Raw hex graffiti (max 64 chars)
- `DecodedGraffiti` - Decoded text graffiti (indexed)
- `Timestamp` - Block timestamp (indexed)
- `ProposerPubkey` - Validator public key
- `CreatedAt` - Record creation timestamp

### Validator
- `Id` - Primary key
- `ValidatorIndex` - Unique validator index
- `Pubkey` - Validator public key (unique)
- `WithdrawalAddress` - Withdrawal credentials
- `EffectiveBalance` - Current effective balance
- `IsActive` - Active status (indexed)
- `ActivationEpoch` - Activation epoch
- `ExitEpoch` - Exit epoch
- `CreatedAt`, `UpdatedAt` - Timestamps

### BeaconBlock
- `Id` - Primary key
- `Slot` - Slot number (unique, indexed)
- `Epoch` - Epoch number
- `BlockHash` - Block hash (unique, indexed)
- `ParentHash` - Parent block hash
- `StateRoot` - State root
- `ProposerIndex` - Proposer validator index (indexed)
- `Graffiti` - Raw graffiti
- `Timestamp` - Block timestamp (indexed)
- `IsProcessed` - Processing status (indexed)
- `CreatedAt` - Record creation timestamp

## API Usage Examples

### Search Graffiti
```bash
curl -X POST https://localhost:7001/api/graffiti/search \
  -H "Content-Type: application/json" \
  -d '{
    "searchTerm": "poappp",
    "pageNumber": 1,
    "pageSize": 50,
    "sortBy": "Timestamp",
    "sortDescending": true
  }'
```

### Get Validator Graffiti
```bash
curl https://localhost:7001/api/graffiti/validator/12345
```

### Get Top Graffiti
```bash
curl https://localhost:7001/api/graffiti/top?count=20
```

## Graffiti Decoding

The `GraffitiDecoder` class handles conversion of hex-encoded graffiti to readable text:

- Strips hex prefix (0x)
- Removes trailing zero padding
- Converts to UTF-8 text
- Replaces non-printable characters with hex escape sequences
- Handles various encoding edge cases

## Development

### Adding Migrations
```bash
cd EthGraffitiExplorer.Api
dotnet ef migrations add MigrationName --project ../EthGraffitiExplorer.Core/EthGraffitiExplorer.Core.csproj
```

### Building for Production
```bash
dotnet publish -c Release
```

## Technology Stack

- **.NET 8/9** - Core framework
- **ASP.NET Core** - Web API
- **Blazor Server** - Web UI
- **.NET MAUI** - Mobile apps
- **Entity Framework Core** - ORM
- **SQL Server** - Database
- **Nethereum** - Ethereum integration
- **Swagger/OpenAPI** - API documentation

## License

MIT License - Feel free to use this for your own beacon chain exploration!

## Contributing

Contributions welcome! Please open an issue or pull request.

## Support

For issues or questions, please open a GitHub issue.
