using EthGraffitiExplorer.Core.Models;

namespace EthGraffitiExplorer.Core.Interfaces;

public interface IValidatorRepository
{
    Task<Validator?> GetByIdAsync(int id);
    Task<Validator?> GetByIndexAsync(int validatorIndex);
    Task<Validator?> GetByPubkeyAsync(string pubkey);
    Task<List<Validator>> GetActiveValidatorsAsync(int limit = 100);
    Task<Validator> AddAsync(Validator validator);
    Task<Validator> UpdateAsync(Validator validator);
    Task<bool> ExistsAsync(int validatorIndex);
}
