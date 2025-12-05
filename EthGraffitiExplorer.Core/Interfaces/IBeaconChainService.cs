using EthGraffitiExplorer.Core.Models;

namespace EthGraffitiExplorer.Core.Interfaces;

public interface IBeaconChainService
{
    Task<BeaconBlock?> GetBlockBySlotAsync(long slot);
    Task<List<BeaconBlock>> GetBlocksInRangeAsync(long fromSlot, long toSlot);
    Task<long> GetCurrentSlotAsync();
    Task<long> GetFinalizedSlotAsync();
    Task<Validator?> GetValidatorByIndexAsync(int validatorIndex);
    Task<bool> IsNodeHealthyAsync();
}
