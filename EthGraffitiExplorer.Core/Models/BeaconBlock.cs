namespace EthGraffitiExplorer.Core.Models;

public class BeaconBlock
{
    public int Id { get; set; }
    
    public long Slot { get; set; }
    
    public long Epoch { get; set; }
    
    public string BlockHash { get; set; } = string.Empty;
    
    public string? ParentHash { get; set; }
    
    public string StateRoot { get; set; } = string.Empty;
    
    public int ProposerIndex { get; set; }
    
    public string Graffiti { get; set; } = string.Empty;
    
    public DateTime Timestamp { get; set; }
    
    public bool IsProcessed { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
