namespace EthGraffitiExplorer.Core.Configuration;

public class MongoDbSettings
{
    public string ConnectionString { get; set; } = "mongodb://localhost:27017";
    public string DatabaseName { get; set; } = "EthGraffitiExplorer";
    public string GraffitiCollectionName { get; set; } = "graffiti";
}
