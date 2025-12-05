-- Create database if not exists
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'EthGraffitiExplorer')
BEGIN
    CREATE DATABASE EthGraffitiExplorer;
END
GO

USE EthGraffitiExplorer;
GO

-- Validators table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Validators')
BEGIN
    CREATE TABLE Validators (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ValidatorIndex INT NOT NULL UNIQUE,
        Pubkey NVARCHAR(98) NOT NULL UNIQUE,
        WithdrawalAddress NVARCHAR(42) NULL,
        EffectiveBalance BIGINT NOT NULL,
        IsActive BIT NOT NULL,
        ActivationEpoch BIGINT NULL,
        ExitEpoch BIGINT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_Validators_IsActive ON Validators(IsActive);
    CREATE INDEX IX_Validators_ValidatorIndex ON Validators(ValidatorIndex);
END
GO

-- BeaconBlocks table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BeaconBlocks')
BEGIN
    CREATE TABLE BeaconBlocks (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Slot BIGINT NOT NULL UNIQUE,
        Epoch BIGINT NOT NULL,
        BlockHash NVARCHAR(66) NOT NULL UNIQUE,
        ParentHash NVARCHAR(66) NULL,
        StateRoot NVARCHAR(66) NOT NULL,
        ProposerIndex INT NOT NULL,
        Graffiti NVARCHAR(64) NULL,
        Timestamp DATETIME2 NOT NULL,
        IsProcessed BIT NOT NULL DEFAULT 0,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_BeaconBlocks_Slot ON BeaconBlocks(Slot);
    CREATE INDEX IX_BeaconBlocks_BlockHash ON BeaconBlocks(BlockHash);
    CREATE INDEX IX_BeaconBlocks_Timestamp ON BeaconBlocks(Timestamp);
    CREATE INDEX IX_BeaconBlocks_ProposerIndex ON BeaconBlocks(ProposerIndex);
    CREATE INDEX IX_BeaconBlocks_IsProcessed ON BeaconBlocks(IsProcessed);
END
GO
