using Microsoft.EntityFrameworkCore;
using EthGraffitiExplorer.Core.Data;
using EthGraffitiExplorer.Core.Models;
using EthGraffitiExplorer.Core.Interfaces;

namespace EthGraffitiExplorer.Core.Repositories;

public class ValidatorRepository : IValidatorRepository
{
    private readonly GraffitiDbContext _context;

    public ValidatorRepository(GraffitiDbContext context)
    {
        _context = context;
    }

    public async Task<Validator?> GetByIdAsync(int id)
    {
        return await _context.Validators
            .Include(v => v.Graffitis)
            .FirstOrDefaultAsync(v => v.Id == id);
    }

    public async Task<Validator?> GetByIndexAsync(int validatorIndex)
    {
        return await _context.Validators
            .Include(v => v.Graffitis)
            .FirstOrDefaultAsync(v => v.ValidatorIndex == validatorIndex);
    }

    public async Task<Validator?> GetByPubkeyAsync(string pubkey)
    {
        return await _context.Validators
            .Include(v => v.Graffitis)
            .FirstOrDefaultAsync(v => v.Pubkey == pubkey);
    }

    public async Task<List<Validator>> GetActiveValidatorsAsync(int limit = 100)
    {
        return await _context.Validators
            .Where(v => v.IsActive)
            .OrderBy(v => v.ValidatorIndex)
            .Take(limit)
            .ToListAsync();
    }

    public async Task<Validator> AddAsync(Validator validator)
    {
        _context.Validators.Add(validator);
        await _context.SaveChangesAsync();
        return validator;
    }

    public async Task<Validator> UpdateAsync(Validator validator)
    {
        validator.UpdatedAt = DateTime.UtcNow;
        _context.Validators.Update(validator);
        await _context.SaveChangesAsync();
        return validator;
    }

    public async Task<bool> ExistsAsync(int validatorIndex)
    {
        return await _context.Validators
            .AnyAsync(v => v.ValidatorIndex == validatorIndex);
    }
}
