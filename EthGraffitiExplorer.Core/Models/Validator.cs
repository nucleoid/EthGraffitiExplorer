namespace EthGraffitiExplorer.Core.Models;

public class Validator
{
    public int Id { get; set; }
    
    public int ValidatorIndex { get; set; }
    
    public string Pubkey { get; set; } = string.Empty;
    
    public string? WithdrawalAddress { get; set; }
    
    public long EffectiveBalance { get; set; }
    
    public bool IsActive { get; set; }
    
    public long? ActivationEpoch { get; set; }
    
    public long? ExitEpoch { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    
    public ICollection<ValidatorGraffiti> Graffitis { get; set; } = new List<ValidatorGraffiti>();
}
