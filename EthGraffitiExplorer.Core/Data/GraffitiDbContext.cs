using Microsoft.EntityFrameworkCore;
using EthGraffitiExplorer.Core.Models;

namespace EthGraffitiExplorer.Core.Data;

public class GraffitiDbContext : DbContext
{
    public GraffitiDbContext(DbContextOptions<GraffitiDbContext> options)
        : base(options)
    {
    }

    public DbSet<ValidatorGraffiti> Graffitis { get; set; }
    public DbSet<Validator> Validators { get; set; }
    public DbSet<BeaconBlock> BeaconBlocks { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // ValidatorGraffiti configuration
        modelBuilder.Entity<ValidatorGraffiti>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Slot);
            entity.HasIndex(e => e.ValidatorIndex);
            entity.HasIndex(e => e.BlockHash);
            entity.HasIndex(e => e.Timestamp);
            entity.HasIndex(e => e.DecodedGraffiti);
            
            entity.Property(e => e.RawGraffiti).HasMaxLength(64);
            entity.Property(e => e.DecodedGraffiti).HasMaxLength(256);
            entity.Property(e => e.BlockHash).HasMaxLength(66).IsRequired();
            entity.Property(e => e.ProposerPubkey).HasMaxLength(98);
        });

        // Validator configuration
        modelBuilder.Entity<Validator>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.ValidatorIndex).IsUnique();
            entity.HasIndex(e => e.Pubkey).IsUnique();
            entity.HasIndex(e => e.IsActive);
            
            entity.Property(e => e.Pubkey).HasMaxLength(98).IsRequired();
            entity.Property(e => e.WithdrawalAddress).HasMaxLength(42);
            
            entity.HasMany(e => e.Graffitis)
                .WithOne()
                .HasForeignKey(e => e.ValidatorIndex)
                .HasPrincipalKey(e => e.ValidatorIndex)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // BeaconBlock configuration
        modelBuilder.Entity<BeaconBlock>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Slot).IsUnique();
            entity.HasIndex(e => e.BlockHash).IsUnique();
            entity.HasIndex(e => e.Timestamp);
            entity.HasIndex(e => e.ProposerIndex);
            entity.HasIndex(e => e.IsProcessed);
            
            entity.Property(e => e.BlockHash).HasMaxLength(66).IsRequired();
            entity.Property(e => e.ParentHash).HasMaxLength(66);
            entity.Property(e => e.StateRoot).HasMaxLength(66).IsRequired();
            entity.Property(e => e.Graffiti).HasMaxLength(64);
        });
    }
}
