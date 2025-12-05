using EthGraffitiExplorer.Core.Models;

namespace EthGraffitiExplorer.Core.Interfaces;

public interface IBeaconBlockRepository
{
    Task<BeaconBlock?> GetByIdAsync(int id);
    Task<BeaconBlock?> GetBySlotAsync(long slot);
    Task<BeaconBlock?> GetByBlockHashAsync(string blockHash);
    Task<List<BeaconBlock>> GetUnprocessedAsync(int limit = 100);
    Task<BeaconBlock> AddAsync(BeaconBlock block);
    Task<BeaconBlock> UpdateAsync(BeaconBlock block);
    Task<bool> ExistsAsync(long slot);
    Task<long?> GetLatestProcessedSlotAsync();
}
