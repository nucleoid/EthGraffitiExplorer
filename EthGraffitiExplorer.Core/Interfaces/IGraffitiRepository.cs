using EthGraffitiExplorer.Core.Models;
using EthGraffitiExplorer.Core.DTOs;

namespace EthGraffitiExplorer.Core.Interfaces;

public interface IGraffitiRepository
{
    Task<ValidatorGraffiti?> GetByIdAsync(int id);
    Task<PagedResult<ValidatorGraffiti>> SearchAsync(GraffitiSearchRequest request);
    Task<List<ValidatorGraffiti>> GetByValidatorIndexAsync(int validatorIndex, int limit = 100);
    Task<List<ValidatorGraffiti>> GetRecentAsync(int count = 50);
    Task<ValidatorGraffiti> AddAsync(ValidatorGraffiti graffiti);
    Task<bool> ExistsAsync(long slot, string blockHash);
    Task<int> GetCountAsync();
    Task<Dictionary<string, int>> GetTopGraffitiAsync(int count = 20);
}
