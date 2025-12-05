using Microsoft.EntityFrameworkCore;
using EthGraffitiExplorer.Core.Data;
using EthGraffitiExplorer.Core.Models;
using EthGraffitiExplorer.Core.Interfaces;

namespace EthGraffitiExplorer.Core.Repositories;

public class BeaconBlockRepository : IBeaconBlockRepository
{
    private readonly GraffitiDbContext _context;

    public BeaconBlockRepository(GraffitiDbContext context)
    {
        _context = context;
    }

    public async Task<BeaconBlock?> GetByIdAsync(int id)
    {
        return await _context.BeaconBlocks.FindAsync(id);
    }

    public async Task<BeaconBlock?> GetBySlotAsync(long slot)
    {
        return await _context.BeaconBlocks
            .FirstOrDefaultAsync(b => b.Slot == slot);
    }

    public async Task<BeaconBlock?> GetByBlockHashAsync(string blockHash)
    {
        return await _context.BeaconBlocks
            .FirstOrDefaultAsync(b => b.BlockHash == blockHash);
    }

    public async Task<List<BeaconBlock>> GetUnprocessedAsync(int limit = 100)
    {
        return await _context.BeaconBlocks
            .Where(b => !b.IsProcessed)
            .OrderBy(b => b.Slot)
            .Take(limit)
            .ToListAsync();
    }

    public async Task<BeaconBlock> AddAsync(BeaconBlock block)
    {
        _context.BeaconBlocks.Add(block);
        await _context.SaveChangesAsync();
        return block;
    }

    public async Task<BeaconBlock> UpdateAsync(BeaconBlock block)
    {
        _context.BeaconBlocks.Update(block);
        await _context.SaveChangesAsync();
        return block;
    }

    public async Task<bool> ExistsAsync(long slot)
    {
        return await _context.BeaconBlocks
            .AnyAsync(b => b.Slot == slot);
    }

    public async Task<long?> GetLatestProcessedSlotAsync()
    {
        return await _context.BeaconBlocks
            .Where(b => b.IsProcessed)
            .OrderByDescending(b => b.Slot)
            .Select(b => (long?)b.Slot)
            .FirstOrDefaultAsync();
    }
}
