using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using EthGraffitiExplorer.Core.Models;
using EthGraffitiExplorer.Core.Interfaces;

namespace EthGraffitiExplorer.Core.Repositories.Dapper;

public class DapperValidatorRepository : IValidatorRepository
{
    private readonly string _connectionString;

    public DapperValidatorRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new ArgumentNullException("DefaultConnection not configured");
    }

    private IDbConnection CreateConnection() => new SqlConnection(_connectionString);

    public async Task<Validator?> GetByIdAsync(int id)
    {
        using var connection = CreateConnection();
        const string sql = @"
            SELECT * FROM Validators WHERE Id = @Id";
        
        return await connection.QueryFirstOrDefaultAsync<Validator>(sql, new { Id = id });
    }

    public async Task<Validator?> GetByIndexAsync(int validatorIndex)
    {
        using var connection = CreateConnection();
        const string sql = @"
            SELECT * FROM Validators WHERE ValidatorIndex = @ValidatorIndex";
        
        return await connection.QueryFirstOrDefaultAsync<Validator>(sql, new { ValidatorIndex = validatorIndex });
    }

    public async Task<Validator?> GetByPubkeyAsync(string pubkey)
    {
        using var connection = CreateConnection();
        const string sql = @"
            SELECT * FROM Validators WHERE Pubkey = @Pubkey";
        
        return await connection.QueryFirstOrDefaultAsync<Validator>(sql, new { Pubkey = pubkey });
    }

    public async Task<List<Validator>> GetActiveValidatorsAsync(int limit = 100)
    {
        using var connection = CreateConnection();
        const string sql = @"
            SELECT TOP(@Limit) * FROM Validators 
            WHERE IsActive = 1 
            ORDER BY ValidatorIndex";
        
        var validators = await connection.QueryAsync<Validator>(sql, new { Limit = limit });
        return validators.ToList();
    }

    public async Task<Validator> AddAsync(Validator validator)
    {
        using var connection = CreateConnection();
        const string sql = @"
            INSERT INTO Validators 
            (ValidatorIndex, Pubkey, WithdrawalAddress, EffectiveBalance, IsActive, 
             ActivationEpoch, ExitEpoch, CreatedAt, UpdatedAt)
            VALUES 
            (@ValidatorIndex, @Pubkey, @WithdrawalAddress, @EffectiveBalance, @IsActive, 
             @ActivationEpoch, @ExitEpoch, @CreatedAt, @UpdatedAt);
            
            SELECT CAST(SCOPE_IDENTITY() as int)";
        
        validator.CreatedAt = DateTime.UtcNow;
        validator.UpdatedAt = DateTime.UtcNow;
        
        var id = await connection.ExecuteScalarAsync<int>(sql, validator);
        validator.Id = id;
        
        return validator;
    }

    public async Task<Validator> UpdateAsync(Validator validator)
    {
        using var connection = CreateConnection();
        const string sql = @"
            UPDATE Validators 
            SET ValidatorIndex = @ValidatorIndex,
                Pubkey = @Pubkey,
                WithdrawalAddress = @WithdrawalAddress,
                EffectiveBalance = @EffectiveBalance,
                IsActive = @IsActive,
                ActivationEpoch = @ActivationEpoch,
                ExitEpoch = @ExitEpoch,
                UpdatedAt = @UpdatedAt
            WHERE Id = @Id";
        
        validator.UpdatedAt = DateTime.UtcNow;
        
        await connection.ExecuteAsync(sql, validator);
        return validator;
    }

    public async Task<bool> ExistsAsync(int validatorIndex)
    {
        using var connection = CreateConnection();
        const string sql = @"
            SELECT CAST(COUNT(1) AS BIT) FROM Validators WHERE ValidatorIndex = @ValidatorIndex";
        
        return await connection.ExecuteScalarAsync<bool>(sql, new { ValidatorIndex = validatorIndex });
    }
}
