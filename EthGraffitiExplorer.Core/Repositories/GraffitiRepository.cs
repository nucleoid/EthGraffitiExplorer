using Microsoft.EntityFrameworkCore;
using EthGraffitiExplorer.Core.Data;
using EthGraffitiExplorer.Core.Models;
using EthGraffitiExplorer.Core.DTOs;
using EthGraffitiExplorer.Core.Interfaces;

namespace EthGraffitiExplorer.Core.Repositories;

public class GraffitiRepository : IGraffitiRepository
{
    private readonly GraffitiDbContext _context;

    public GraffitiRepository(GraffitiDbContext context)
    {
        _context = context;
    }

    public async Task<ValidatorGraffiti?> GetByIdAsync(int id)
    {
        return await _context.Graffitis.FindAsync(id);
    }

    public async Task<PagedResult<ValidatorGraffiti>> SearchAsync(GraffitiSearchRequest request)
    {
        var query = _context.Graffitis.AsQueryable();

        // Apply filters
        if (!string.IsNullOrWhiteSpace(request.SearchTerm))
        {
            query = query.Where(g => g.DecodedGraffiti.Contains(request.SearchTerm));
        }

        if (request.ValidatorIndex.HasValue)
        {
            query = query.Where(g => g.ValidatorIndex == request.ValidatorIndex.Value);
        }

        if (request.FromSlot.HasValue)
        {
            query = query.Where(g => g.Slot >= request.FromSlot.Value);
        }

        if (request.ToSlot.HasValue)
        {
            query = query.Where(g => g.Slot <= request.ToSlot.Value);
        }

        if (request.FromDate.HasValue)
        {
            query = query.Where(g => g.Timestamp >= request.FromDate.Value);
        }

        if (request.ToDate.HasValue)
        {
            query = query.Where(g => g.Timestamp <= request.ToDate.Value);
        }

        // Get total count before pagination
        var totalCount = await query.CountAsync();

        // Apply sorting
        query = request.SortBy.ToLower() switch
        {
            "slot" => request.SortDescending ? query.OrderByDescending(g => g.Slot) : query.OrderBy(g => g.Slot),
            "validatorindex" => request.SortDescending ? query.OrderByDescending(g => g.ValidatorIndex) : query.OrderBy(g => g.ValidatorIndex),
            _ => request.SortDescending ? query.OrderByDescending(g => g.Timestamp) : query.OrderBy(g => g.Timestamp)
        };

        // Apply pagination
        var items = await query
            .Skip((request.PageNumber - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync();

        return new PagedResult<ValidatorGraffiti>
        {
            Items = items,
            PageNumber = request.PageNumber,
            PageSize = request.PageSize,
            TotalCount = totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)request.PageSize)
        };
    }

    public async Task<List<ValidatorGraffiti>> GetByValidatorIndexAsync(int validatorIndex, int limit = 100)
    {
        return await _context.Graffitis
            .Where(g => g.ValidatorIndex == validatorIndex)
            .OrderByDescending(g => g.Timestamp)
            .Take(limit)
            .ToListAsync();
    }

    public async Task<List<ValidatorGraffiti>> GetRecentAsync(int count = 50)
    {
        return await _context.Graffitis
            .OrderByDescending(g => g.Timestamp)
            .Take(count)
            .ToListAsync();
    }

    public async Task<ValidatorGraffiti> AddAsync(ValidatorGraffiti graffiti)
    {
        _context.Graffitis.Add(graffiti);
        await _context.SaveChangesAsync();
        return graffiti;
    }

    public async Task<bool> ExistsAsync(long slot, string blockHash)
    {
        return await _context.Graffitis
            .AnyAsync(g => g.Slot == slot && g.BlockHash == blockHash);
    }

    public async Task<int> GetCountAsync()
    {
        return await _context.Graffitis.CountAsync();
    }

    public async Task<Dictionary<string, int>> GetTopGraffitiAsync(int count = 20)
    {
        return await _context.Graffitis
            .Where(g => !string.IsNullOrEmpty(g.DecodedGraffiti))
            .GroupBy(g => g.DecodedGraffiti)
            .Select(g => new { Graffiti = g.Key, Count = g.Count() })
            .OrderByDescending(x => x.Count)
            .Take(count)
            .ToDictionaryAsync(x => x.Graffiti, x => x.Count);
    }
}
