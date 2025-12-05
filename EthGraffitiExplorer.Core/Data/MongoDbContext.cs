using MongoDB.Driver;
using Microsoft.Extensions.Options;
using EthGraffitiExplorer.Core.Configuration;
using EthGraffitiExplorer.Core.Models.Mongo;

namespace EthGraffitiExplorer.Core.Data;

public class MongoDbContext
{
    private readonly IMongoDatabase _database;
    private readonly MongoDbSettings _settings;

    public MongoDbContext(IOptions<MongoDbSettings> settings)
    {
        _settings = settings.Value;
        var client = new MongoClient(_settings.ConnectionString);
        _database = client.GetDatabase(_settings.DatabaseName);
        
        // Create indexes on initialization
        CreateIndexes();
    }

    public IMongoCollection<GraffitiDocument> Graffiti =>
        _database.GetCollection<GraffitiDocument>(_settings.GraffitiCollectionName);

    private void CreateIndexes()
    {
        var graffitiCollection = Graffiti;
        
        // Create indexes for common queries
        var indexKeys = Builders<GraffitiDocument>.IndexKeys;
        
        // Slot index (ascending for chronological queries)
        graffitiCollection.Indexes.CreateOne(
            new CreateIndexModel<GraffitiDocument>(indexKeys.Ascending(g => g.Slot)));
        
        // ValidatorIndex index
        graffitiCollection.Indexes.CreateOne(
            new CreateIndexModel<GraffitiDocument>(indexKeys.Ascending(g => g.ValidatorIndex)));
        
        // BlockHash index (unique)
        graffitiCollection.Indexes.CreateOne(
            new CreateIndexModel<GraffitiDocument>(
                indexKeys.Ascending(g => g.BlockHash),
                new CreateIndexOptions { Unique = true }));
        
        // Timestamp index (descending for recent queries)
        graffitiCollection.Indexes.CreateOne(
            new CreateIndexModel<GraffitiDocument>(indexKeys.Descending(g => g.Timestamp)));
        
        // Text index on decoded graffiti for search
        graffitiCollection.Indexes.CreateOne(
            new CreateIndexModel<GraffitiDocument>(indexKeys.Text(g => g.DecodedGraffiti)));
        
        // Compound index for validator + timestamp queries
        graffitiCollection.Indexes.CreateOne(
            new CreateIndexModel<GraffitiDocument>(
                indexKeys.Ascending(g => g.ValidatorIndex).Descending(g => g.Timestamp)));
    }
}
