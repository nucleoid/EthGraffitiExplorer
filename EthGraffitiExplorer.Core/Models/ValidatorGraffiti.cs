namespace EthGraffitiExplorer.Core.Models;

public class ValidatorGraffiti
{
    public int Id { get; set; }
    
    public long Slot { get; set; }
    
    public long Epoch { get; set; }
    
    public long BlockNumber { get; set; }
    
    public string BlockHash { get; set; } = string.Empty;
    
    public int ValidatorIndex { get; set; }
    
    public string RawGraffiti { get; set; } = string.Empty;
    
    public string DecodedGraffiti { get; set; } = string.Empty;
    
    public DateTime Timestamp { get; set; }
    
    public string? ProposerPubkey { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
