namespace EthGraffitiExplorer.Core.DTOs;

public class ValidatorDto
{
    public int ValidatorIndex { get; set; }
    
    public string Pubkey { get; set; } = string.Empty;
    
    public string? WithdrawalAddress { get; set; }
    
    public long EffectiveBalance { get; set; }
    
    public bool IsActive { get; set; }
    
    public long? ActivationEpoch { get; set; }
    
    public long? ExitEpoch { get; set; }
    
    public int GraffitiCount { get; set; }
}
