using MongoDB.Driver;
using MongoDB.Driver.Linq;
using EthGraffitiExplorer.Core.Data;
using EthGraffitiExplorer.Core.Models.Mongo;
using EthGraffitiExplorer.Core.DTOs;
using EthGraffitiExplorer.Core.Interfaces;
using EthGraffitiExplorer.Core.Models;

namespace EthGraffitiExplorer.Core.Repositories.Mongo;

public class MongoGraffitiRepository : IGraffitiRepository
{
    private readonly MongoDbContext _context;
    private readonly IMongoCollection<GraffitiDocument> _collection;

    public MongoGraffitiRepository(MongoDbContext context)
    {
        _context = context;
        _collection = context.Graffiti;
    }

    public async Task<ValidatorGraffiti?> GetByIdAsync(int id)
    {
        // MongoDB uses ObjectId, but we'll search by internal numeric ID if stored
        // For this implementation, we'll use the MongoDB _id as string
        return null; // This method is less relevant with MongoDB's ObjectId
    }

    public async Task<ValidatorGraffiti?> GetByMongoIdAsync(string id)
    {
        var doc = await _collection.Find(g => g.Id == id).FirstOrDefaultAsync();
        return doc != null ? MapToValidatorGraffiti(doc) : null;
    }

    public async Task<PagedResult<ValidatorGraffiti>> SearchAsync(GraffitiSearchRequest request)
    {
        var filterBuilder = Builders<GraffitiDocument>.Filter;
        var filters = new List<FilterDefinition<GraffitiDocument>>();

        // Apply search term filter (text search)
        if (!string.IsNullOrWhiteSpace(request.SearchTerm))
        {
            filters.Add(filterBuilder.Text(request.SearchTerm));
        }

        // Apply validator index filter
        if (request.ValidatorIndex.HasValue)
        {
            filters.Add(filterBuilder.Eq(g => g.ValidatorIndex, request.ValidatorIndex.Value));
        }

        // Apply slot range filters
        if (request.FromSlot.HasValue)
        {
            filters.Add(filterBuilder.Gte(g => g.Slot, request.FromSlot.Value));
        }

        if (request.ToSlot.HasValue)
        {
            filters.Add(filterBuilder.Lte(g => g.Slot, request.ToSlot.Value));
        }

        // Apply date range filters
        if (request.FromDate.HasValue)
        {
            filters.Add(filterBuilder.Gte(g => g.Timestamp, request.FromDate.Value));
        }

        if (request.ToDate.HasValue)
        {
            filters.Add(filterBuilder.Lte(g => g.Timestamp, request.ToDate.Value));
        }

        // Combine filters
        var filter = filters.Any() 
            ? filterBuilder.And(filters) 
            : filterBuilder.Empty;

        // Get total count
        var totalCount = await _collection.CountDocumentsAsync(filter);

        // Apply sorting
        var sortBuilder = Builders<GraffitiDocument>.Sort;
        var sort = request.SortBy.ToLower() switch
        {
            "slot" => request.SortDescending 
                ? sortBuilder.Descending(g => g.Slot) 
                : sortBuilder.Ascending(g => g.Slot),
            "validatorindex" => request.SortDescending 
                ? sortBuilder.Descending(g => g.ValidatorIndex) 
                : sortBuilder.Ascending(g => g.ValidatorIndex),
            _ => request.SortDescending 
                ? sortBuilder.Descending(g => g.Timestamp) 
                : sortBuilder.Ascending(g => g.Timestamp)
        };

        // Execute query with pagination
        var documents = await _collection
            .Find(filter)
            .Sort(sort)
            .Skip((request.PageNumber - 1) * request.PageSize)
            .Limit(request.PageSize)
            .ToListAsync();

        var items = documents.Select(MapToValidatorGraffiti).ToList();

        return new PagedResult<ValidatorGraffiti>
        {
            Items = items,
            PageNumber = request.PageNumber,
            PageSize = request.PageSize,
            TotalCount = (int)totalCount,
            TotalPages = (int)Math.Ceiling(totalCount / (double)request.PageSize)
        };
    }

    public async Task<List<ValidatorGraffiti>> GetByValidatorIndexAsync(int validatorIndex, int limit = 100)
    {
        var documents = await _collection
            .Find(g => g.ValidatorIndex == validatorIndex)
            .SortByDescending(g => g.Timestamp)
            .Limit(limit)
            .ToListAsync();

        return documents.Select(MapToValidatorGraffiti).ToList();
    }

    public async Task<List<ValidatorGraffiti>> GetRecentAsync(int count = 50)
    {
        var documents = await _collection
            .Find(Builders<GraffitiDocument>.Filter.Empty)
            .SortByDescending(g => g.Timestamp)
            .Limit(count)
            .ToListAsync();

        return documents.Select(MapToValidatorGraffiti).ToList();
    }

    public async Task<ValidatorGraffiti> AddAsync(ValidatorGraffiti graffiti)
    {
        var document = MapToGraffitiDocument(graffiti);
        await _collection.InsertOneAsync(document);
        
        // Update the graffiti with the MongoDB-generated ID
        graffiti.Id = int.Parse(document.Id.GetHashCode().ToString());
        return graffiti;
    }

    public async Task<bool> ExistsAsync(long slot, string blockHash)
    {
        var filter = Builders<GraffitiDocument>.Filter.And(
            Builders<GraffitiDocument>.Filter.Eq(g => g.Slot, slot),
            Builders<GraffitiDocument>.Filter.Eq(g => g.BlockHash, blockHash)
        );

        var count = await _collection.CountDocumentsAsync(filter);
        return count > 0;
    }

    public async Task<int> GetCountAsync()
    {
        var count = await _collection.CountDocumentsAsync(Builders<GraffitiDocument>.Filter.Empty);
        return (int)count;
    }

    public async Task<Dictionary<string, int>> GetTopGraffitiAsync(int count = 20)
    {
        var pipeline = _collection.Aggregate()
            .Match(Builders<GraffitiDocument>.Filter.Ne(g => g.DecodedGraffiti, ""))
            .Group(
                g => g.DecodedGraffiti,
                g => new { Graffiti = g.Key, Count = g.Count() }
            )
            .SortByDescending(g => g.Count)
            .Limit(count);

        var results = await pipeline.ToListAsync();
        return results.ToDictionary(r => r.Graffiti, r => r.Count);
    }

    private ValidatorGraffiti MapToValidatorGraffiti(GraffitiDocument doc)
    {
        return new ValidatorGraffiti
        {
            Id = doc.Id.GetHashCode(), // Use hash of MongoDB ObjectId as integer ID
            Slot = doc.Slot,
            Epoch = doc.Epoch,
            BlockNumber = doc.BlockNumber,
            BlockHash = doc.BlockHash,
            ValidatorIndex = doc.ValidatorIndex,
            RawGraffiti = doc.RawGraffiti,
            DecodedGraffiti = doc.DecodedGraffiti,
            Timestamp = doc.Timestamp,
            ProposerPubkey = doc.ProposerPubkey,
            CreatedAt = doc.CreatedAt
        };
    }

    private GraffitiDocument MapToGraffitiDocument(ValidatorGraffiti graffiti)
    {
        return new GraffitiDocument
        {
            Slot = graffiti.Slot,
            Epoch = graffiti.Epoch,
            BlockNumber = graffiti.BlockNumber,
            BlockHash = graffiti.BlockHash,
            ValidatorIndex = graffiti.ValidatorIndex,
            RawGraffiti = graffiti.RawGraffiti,
            DecodedGraffiti = graffiti.DecodedGraffiti,
            Timestamp = graffiti.Timestamp,
            ProposerPubkey = graffiti.ProposerPubkey,
            CreatedAt = graffiti.CreatedAt
        };
    }
}
