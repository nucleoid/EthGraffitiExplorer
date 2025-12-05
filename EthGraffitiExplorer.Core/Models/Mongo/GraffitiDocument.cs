using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace EthGraffitiExplorer.Core.Models.Mongo;

public class GraffitiDocument
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; } = ObjectId.GenerateNewId().ToString();
    
    [BsonElement("slot")]
    public long Slot { get; set; }
    
    [BsonElement("epoch")]
    public long Epoch { get; set; }
    
    [BsonElement("blockNumber")]
    public long BlockNumber { get; set; }
    
    [BsonElement("blockHash")]
    public string BlockHash { get; set; } = string.Empty;
    
    [BsonElement("validatorIndex")]
    public int ValidatorIndex { get; set; }
    
    [BsonElement("rawGraffiti")]
    public string RawGraffiti { get; set; } = string.Empty;
    
    [BsonElement("decodedGraffiti")]
    public string DecodedGraffiti { get; set; } = string.Empty;
    
    [BsonElement("timestamp")]
    [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
    public DateTime Timestamp { get; set; }
    
    [BsonElement("proposerPubkey")]
    public string? ProposerPubkey { get; set; }
    
    [BsonElement("createdAt")]
    [BsonDateTimeOptions(Kind = DateTimeKind.Utc)]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    [BsonElement("metadata")]
    public GraffitiMetadata? Metadata { get; set; }
}

public class GraffitiMetadata
{
    [BsonElement("hasNonPrintable")]
    public bool HasNonPrintableCharacters { get; set; }
    
    [BsonElement("decodingMethod")]
    public string DecodingMethod { get; set; } = "UTF8";
    
    [BsonElement("tags")]
    public List<string> Tags { get; set; } = new();
}
