namespace EthGraffitiExplorer.Core.DTOs;

public class GraffitiSearchRequest
{
    public string? SearchTerm { get; set; }
    
    public int? ValidatorIndex { get; set; }
    
    public long? FromSlot { get; set; }
    
    public long? ToSlot { get; set; }
    
    public DateTime? FromDate { get; set; }
    
    public DateTime? ToDate { get; set; }
    
    public int PageNumber { get; set; } = 1;
    
    public int PageSize { get; set; } = 50;
    
    public string SortBy { get; set; } = "Timestamp";
    
    public bool SortDescending { get; set; } = true;
}
