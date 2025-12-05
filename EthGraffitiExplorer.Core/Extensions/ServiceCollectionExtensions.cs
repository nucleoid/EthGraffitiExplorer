using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using EthGraffitiExplorer.Core.Configuration;
using EthGraffitiExplorer.Core.Data;
using EthGraffitiExplorer.Core.Interfaces;
using EthGraffitiExplorer.Core.Repositories.Dapper;
using EthGraffitiExplorer.Core.Repositories.Mongo;
using EthGraffitiExplorer.Core.Services;

namespace EthGraffitiExplorer.Core.Extensions;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Adds Graffiti Explorer services with MongoDB for graffiti storage and SQL Server with Dapper for relational data
    /// </summary>
    public static IServiceCollection AddGraffitiExplorerCore(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // MongoDB configuration for graffiti storage
        services.Configure<MongoDbSettings>(configuration.GetSection("MongoDB"));
        services.AddSingleton<MongoDbContext>();

        // SQL Server is still available via EF Core for potential admin/migration tasks
        var connectionString = configuration.GetConnectionString("DefaultConnection");
        services.AddDbContext<GraffitiDbContext>(options =>
            options.UseSqlServer(connectionString));

        // Repositories - Using Dapper for SQL and MongoDB for graffiti
        services.AddScoped<IGraffitiRepository, MongoGraffitiRepository>();
        services.AddScoped<IValidatorRepository, DapperValidatorRepository>();
        services.AddScoped<IBeaconBlockRepository, DapperBeaconBlockRepository>();

        // Services
        services.AddHttpClient<IBeaconChainService, BeaconChainService>();

        return services;
    }

    /// <summary>
    /// Alternative: Use EF Core for everything (original implementation)
    /// </summary>
    public static IServiceCollection AddGraffitiExplorerCoreWithEFCore(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection");
        services.AddDbContext<GraffitiDbContext>(options =>
            options.UseSqlServer(connectionString));

        services.AddScoped<IGraffitiRepository, Repositories.GraffitiRepository>();
        services.AddScoped<IValidatorRepository, Repositories.ValidatorRepository>();
        services.AddScoped<IBeaconBlockRepository, Repositories.BeaconBlockRepository>();

        services.AddHttpClient<IBeaconChainService, BeaconChainService>();

        return services;
    }
}
