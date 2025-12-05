using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using EthGraffitiExplorer.Core.Models;
using EthGraffitiExplorer.Core.Interfaces;

namespace EthGraffitiExplorer.Core.Repositories.Dapper;

public class DapperBeaconBlockRepository : IBeaconBlockRepository
{
    private readonly string _connectionString;

    public DapperBeaconBlockRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new ArgumentNullException("DefaultConnection not configured");
    }

    private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

    public async Task<BeaconBlock?> GetByIdAsync(int id)
    {
        using var connection = CreateConnection();
        const string sql = "SELECT * FROM BeaconBlocks WHERE Id = @Id";
        
        return await connection.QueryFirstOrDefaultAsync<BeaconBlock>(sql, new { Id = id });
    }

    public async Task<BeaconBlock?> GetBySlotAsync(long slot)
    {
        using var connection = CreateConnection();
        const string sql = "SELECT * FROM BeaconBlocks WHERE Slot = @Slot";
        
        return await connection.QueryFirstOrDefaultAsync<BeaconBlock>(sql, new { Slot = slot });
    }

    public async Task<BeaconBlock?> GetByBlockHashAsync(string blockHash)
    {
        using var connection = CreateConnection();
        const string sql = "SELECT * FROM BeaconBlocks WHERE BlockHash = @BlockHash";
        
        return await connection.QueryFirstOrDefaultAsync<BeaconBlock>(sql, new { BlockHash = blockHash });
    }

    public async Task<List<BeaconBlock>> GetUnprocessedAsync(int limit = 100)
    {
        using var connection = CreateConnection();
        const string sql = @"
            SELECT TOP(@Limit) * FROM BeaconBlocks 
            WHERE IsProcessed = 0 
            ORDER BY Slot";
        
        var blocks = await connection.QueryAsync<BeaconBlock>(sql, new { Limit = limit });
        return blocks.ToList();
    }

    public async Task<BeaconBlock> AddAsync(BeaconBlock block)
    {
        using var connection = CreateConnection();
        const string sql = @"
            INSERT INTO BeaconBlocks 
            (Slot, Epoch, BlockHash, ParentHash, StateRoot, ProposerIndex, 
             Graffiti, Timestamp, IsProcessed, CreatedAt)
            VALUES 
            (@Slot, @Epoch, @BlockHash, @ParentHash, @StateRoot, @ProposerIndex, 
             @Graffiti, @Timestamp, @IsProcessed, @CreatedAt);
            
            SELECT CAST(SCOPE_IDENTITY() as int)";
        
        block.CreatedAt = DateTime.UtcNow;
        
        var id = await connection.ExecuteScalarAsync<int>(sql, block);
        block.Id = id;
        
        return block;
    }

    public async Task<BeaconBlock> UpdateAsync(BeaconBlock block)
    {
        using var connection = CreateConnection();
        const string sql = @"
            UPDATE BeaconBlocks 
            SET Slot = @Slot,
                Epoch = @Epoch,
                BlockHash = @BlockHash,
                ParentHash = @ParentHash,
                StateRoot = @StateRoot,
                ProposerIndex = @ProposerIndex,
                Graffiti = @Graffiti,
                Timestamp = @Timestamp,
                IsProcessed = @IsProcessed
            WHERE Id = @Id";
        
        await connection.ExecuteAsync(sql, block);
        return block;
    }

    public async Task<bool> ExistsAsync(long slot)
    {
        using var connection = CreateConnection();
        const string sql = "SELECT CAST(COUNT(1) AS BIT) FROM BeaconBlocks WHERE Slot = @Slot";
        
        return await connection.ExecuteScalarAsync<bool>(sql, new { Slot = slot });
    }

    public async Task<long?> GetLatestProcessedSlotAsync()
    {
        using var connection = CreateConnection();
        const string sql = @"
            SELECT TOP 1 Slot FROM BeaconBlocks 
            WHERE IsProcessed = 1 
            ORDER BY Slot DESC";
        
        return await connection.QueryFirstOrDefaultAsync<long?>(sql);
    }
}
