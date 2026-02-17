-- =============================================
-- VMSizes Database - Cleaned Up Schema with Pricing
-- Version 2.0 - FINAL (Azure SQL DB Compatible)
-- Date: 2026-02-16
-- NO USE STATEMENT - Azure SQL DB compatible
-- =============================================

-- =============================================
-- PART 0: Cleanup - Drop new tables if they exist with wrong schema
-- =============================================

PRINT 'Checking for existing new schema tables...';

-- Drop views first (they depend on tables)
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_VMSizesWithPricing')
BEGIN
    DROP VIEW [dbo].[vw_VMSizesWithPricing];
    PRINT 'Dropped existing view: vw_VMSizesWithPricing';
END;

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_PriceComparisonByRegion')
BEGIN
    DROP VIEW [dbo].[vw_PriceComparisonByRegion];
    PRINT 'Dropped existing view: vw_PriceComparisonByRegion';
END;

-- Drop stored procedures
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_UpsertVMSize')
BEGIN
    DROP PROCEDURE [dbo].[usp_UpsertVMSize];
    PRINT 'Dropped existing SP: usp_UpsertVMSize';
END;

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_UpsertVMPricing')
BEGIN
    DROP PROCEDURE [dbo].[usp_UpsertVMPricing];
    PRINT 'Dropped existing SP: usp_UpsertVMPricing';
END;

-- Drop tables in reverse dependency order (child tables first)
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'VMPricing' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[VMPricing];
    PRINT 'Dropped existing table: VMPricing';
END;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizeRegionalAvailability' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[VMSizeRegionalAvailability];
    PRINT 'Dropped existing table: VMSizeRegionalAvailability';
END;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizes' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[VMSizes];
    PRINT 'Dropped existing table: VMSizes (will be recreated with correct schema)';
END;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'DataLoadHistory' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[DataLoadHistory];
    PRINT 'Dropped existing table: DataLoadHistory';
END;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'AzureRegions' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[AzureRegions];
    PRINT 'Dropped existing table: AzureRegions';
END;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'VMFamilies' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[VMFamilies];
    PRINT 'Dropped existing table: VMFamilies';
END;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'PricingModels' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[PricingModels];
    PRINT 'Dropped existing table: PricingModels';
END;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Currencies' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE [dbo].[Currencies];
    PRINT 'Dropped existing table: Currencies';
END;

PRINT 'Cleanup completed - ready to create new schema';
GO

-- =============================================
-- PART 1: Core Dimension Tables (NO FOREIGN KEYS YET)
-- =============================================

-- Azure Regions Reference Table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AzureRegions' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[AzureRegions] (
        RegionID INT IDENTITY(1,1) PRIMARY KEY,
        RegionName NVARCHAR(100) NOT NULL UNIQUE,
        DisplayName NVARCHAR(200) NOT NULL,
        RegionType NVARCHAR(50) NOT NULL,
        Geography NVARCHAR(100) NOT NULL,
        PairedRegion NVARCHAR(100) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        UpdatedDate DATETIME NOT NULL DEFAULT GETDATE()
    );

    CREATE INDEX IX_AzureRegions_Name ON [dbo].[AzureRegions](RegionName);
    CREATE INDEX IX_AzureRegions_Active ON [dbo].[AzureRegions](IsActive);

    PRINT 'Created AzureRegions table';
END
ELSE
BEGIN
    PRINT 'AzureRegions table already exists';
END;

-- VM Families/Categories Reference
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'VMFamilies' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[VMFamilies] (
        FamilyID INT IDENTITY(1,1) PRIMARY KEY,
        FamilyCode NCHAR(1) NOT NULL UNIQUE,
        FamilyName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(500) NULL,
        UseCase NVARCHAR(500) NULL
    );

    CREATE INDEX IX_VMFamilies_Code ON [dbo].[VMFamilies](FamilyCode);

    INSERT INTO [dbo].[VMFamilies] (FamilyCode, FamilyName, Description, UseCase) VALUES
    ('A', 'A-Series', 'Entry-level VMs for dev/test', 'Development and testing workloads'),
    ('B', 'B-Series', 'Burstable VMs', 'Low to moderate CPU usage with burst capability'),
    ('D', 'D-Series', 'General purpose', 'Balanced CPU-to-memory ratio'),
    ('E', 'E-Series', 'Memory optimized', 'High memory-to-CPU ratio'),
    ('F', 'F-Series', 'Compute optimized', 'High CPU-to-memory ratio'),
    ('G', 'G-Series', 'Memory and storage optimized', 'Large memory and storage'),
    ('H', 'H-Series', 'High performance compute', 'HPC workloads'),
    ('L', 'L-Series', 'Storage optimized', 'High disk throughput and IO'),
    ('M', 'M-Series', 'Memory optimized', 'Very large memory workloads'),
    ('N', 'N-Series', 'GPU enabled', 'Graphics and compute intensive workloads');

    PRINT 'Created and populated VMFamilies table';
END
ELSE
BEGIN
    PRINT 'VMFamilies table already exists';
END;

-- Pricing Models/Types
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PricingModels' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[PricingModels] (
        PricingModelID INT IDENTITY(1,1) PRIMARY KEY,
        ModelCode NVARCHAR(50) NOT NULL UNIQUE,
        ModelName NVARCHAR(100) NOT NULL,
        Description NVARCHAR(500) NULL
    );

    CREATE INDEX IX_PricingModels_Code ON [dbo].[PricingModels](ModelCode);

    INSERT INTO [dbo].[PricingModels] (ModelCode, ModelName, Description) VALUES
    ('PayAsYouGo', 'Pay-As-You-Go', 'Standard hourly pricing'),
    ('Reserved1Year', '1-Year Reserved Instance', '1-year commitment with discount'),
    ('Reserved3Year', '3-Year Reserved Instance', '3-year commitment with higher discount'),
    ('Spot', 'Spot Pricing', 'Discounted pricing for interruptible workloads'),
    ('AHB', 'Azure Hybrid Benefit', 'Bring your own license discount');

    PRINT 'Created and populated PricingModels table';
END
ELSE
BEGIN
    PRINT 'PricingModels table already exists';
END;

-- Currency Reference
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Currencies' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Currencies] (
        CurrencyID INT IDENTITY(1,1) PRIMARY KEY,
        CurrencyCode NCHAR(3) NOT NULL UNIQUE,
        CurrencyName NVARCHAR(100) NOT NULL,
        Symbol NVARCHAR(10) NULL
    );

    CREATE INDEX IX_Currencies_Code ON [dbo].[Currencies](CurrencyCode);

    INSERT INTO [dbo].[Currencies] (CurrencyCode, CurrencyName, Symbol) VALUES
    ('USD', 'US Dollar', '$'),
    ('EUR', 'Euro', '€'),
    ('GBP', 'British Pound', '£'),
    ('CAD', 'Canadian Dollar', 'C$'),
    ('AUD', 'Australian Dollar', 'A$');

    PRINT 'Created and populated Currencies table';
END
ELSE
BEGIN
    PRINT 'Currencies table already exists';
END;

-- =============================================
-- PART 2: Main VM Sizes Table (New Schema)
-- =============================================

-- Create NEW VMSizes table (capital S) separate from old vmsizes table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizes' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[VMSizes] (
        VMSizeID INT IDENTITY(1,1) PRIMARY KEY,
        VMSizeName NVARCHAR(100) NOT NULL,
        FamilyID INT NULL,
        vCPUs INT NOT NULL,
        MemoryGB DECIMAL(10,2) NOT NULL,
        TempStorageGB INT NULL,
        MaxDataDisks INT NOT NULL,
        MaxCachedDiskThroughputIOPS INT NULL,
        MaxCachedDiskThroughputMBps INT NULL,
        MaxUncachedDiskThroughputIOPS INT NULL,
        MaxUncachedDiskThroughputMBps INT NULL,
        MaxNICs INT NOT NULL,
        ExpectedNetworkBandwidthMbps INT NULL,
        AcceleratedNetworkingEnabled BIT NOT NULL DEFAULT 0,
        PremiumIOSupported BIT NOT NULL DEFAULT 0,
        EphemeralOSDiskSupported BIT NOT NULL DEFAULT 0,
        EncryptionAtHostSupported BIT NOT NULL DEFAULT 0,
        HibernationSupported BIT NOT NULL DEFAULT 0,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        UpdatedDate DATETIME NOT NULL DEFAULT GETDATE()
    );

    CREATE INDEX IX_VMSizes_Name ON [dbo].[VMSizes](VMSizeName);
    CREATE INDEX IX_VMSizes_vCPUs ON [dbo].[VMSizes](vCPUs);
    CREATE INDEX IX_VMSizes_Memory ON [dbo].[VMSizes](MemoryGB);
    CREATE INDEX IX_VMSizes_Family ON [dbo].[VMSizes](FamilyID);
    CREATE INDEX IX_VMSizes_Active ON [dbo].[VMSizes](IsActive);

    PRINT 'Created VMSizes table (new schema)';
END
ELSE
BEGIN
    PRINT 'VMSizes table already exists';
END;
GO

-- Migrate data from old vmsizes table if it exists
-- Note: Data migration skipped - will be populated by runbooks
-- The old vmsizes table structure may differ, so we'll start fresh
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'vmsizes' AND schema_id = SCHEMA_ID('dbo'))
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizes' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    PRINT 'Old vmsizes table detected - data will be repopulated by GetData-v2 runbook';
    PRINT 'Skipping migration to avoid column mismatch issues';
END;
GO

-- Add foreign key for VMSizes.FamilyID
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_VMSizes_VMFamilies')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizes' AND schema_id = SCHEMA_ID('dbo'))
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMFamilies' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    ALTER TABLE [dbo].[VMSizes]
    ADD CONSTRAINT FK_VMSizes_VMFamilies
    FOREIGN KEY (FamilyID) REFERENCES [dbo].[VMFamilies](FamilyID);

    PRINT 'Added FK: VMSizes.FamilyID -> VMFamilies.FamilyID';
END;

-- =============================================
-- PART 3: Regional Availability
-- =============================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizeRegionalAvailability' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[VMSizeRegionalAvailability] (
        AvailabilityID INT IDENTITY(1,1) PRIMARY KEY,
        VMSizeID INT NOT NULL,
        RegionID INT NOT NULL,
        IsAvailable BIT NOT NULL DEFAULT 1,
        AvailabilityZones NVARCHAR(50) NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        UpdatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT UQ_VMSize_Region UNIQUE (VMSizeID, RegionID)
    );

    CREATE INDEX IX_Availability_VMSize ON [dbo].[VMSizeRegionalAvailability](VMSizeID);
    CREATE INDEX IX_Availability_Region ON [dbo].[VMSizeRegionalAvailability](RegionID);
    CREATE INDEX IX_Availability_Available ON [dbo].[VMSizeRegionalAvailability](IsAvailable);

    PRINT 'Created VMSizeRegionalAvailability table';
END
ELSE
BEGIN
    PRINT 'VMSizeRegionalAvailability table already exists';
END;
GO

-- Migrate regional data from old vmsizes table if it exists
-- Note: Regional data will be populated by GetData-v2 runbook
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'vmsizes' AND schema_id = SCHEMA_ID('dbo'))
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.vmsizes') AND name = 'Region')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizeRegionalAvailability' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    PRINT 'Old vmsizes regional data detected - will be repopulated by GetData-v2 runbook';
    PRINT 'Skipping migration to avoid column mismatch issues';
END;
GO

-- Add foreign keys for VMSizeRegionalAvailability
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_VMSizeRegionalAvailability_VMSizes')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizeRegionalAvailability' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    ALTER TABLE [dbo].[VMSizeRegionalAvailability]
    ADD CONSTRAINT FK_VMSizeRegionalAvailability_VMSizes
    FOREIGN KEY (VMSizeID) REFERENCES [dbo].[VMSizes](VMSizeID);

    PRINT 'Added FK: VMSizeRegionalAvailability.VMSizeID -> VMSizes.VMSizeID';
END;

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_VMSizeRegionalAvailability_AzureRegions')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizeRegionalAvailability' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    ALTER TABLE [dbo].[VMSizeRegionalAvailability]
    ADD CONSTRAINT FK_VMSizeRegionalAvailability_AzureRegions
    FOREIGN KEY (RegionID) REFERENCES [dbo].[AzureRegions](RegionID);

    PRINT 'Added FK: VMSizeRegionalAvailability.RegionID -> AzureRegions.RegionID';
END;

-- =============================================
-- PART 4: VM Pricing Table
-- =============================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'VMPricing' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[VMPricing] (
        PriceID BIGINT IDENTITY(1,1) PRIMARY KEY,
        VMSizeID INT NOT NULL,
        RegionID INT NOT NULL,
        PricingModelID INT NOT NULL,
        CurrencyID INT NOT NULL,
        PricePerHour DECIMAL(18,6) NOT NULL,
        PricePerMonth DECIMAL(18,2) NOT NULL,
        PricePerYear DECIMAL(18,2) NULL,
        OperatingSystem NVARCHAR(50) NOT NULL DEFAULT 'Linux',
        EffectiveDate DATETIME NOT NULL DEFAULT GETDATE(),
        ExpiryDate DATETIME NULL,
        MeterID NVARCHAR(100) NULL,
        ProductName NVARCHAR(200) NULL,
        SkuName NVARCHAR(200) NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
        UpdatedDate DATETIME NOT NULL DEFAULT GETDATE()
    );

    CREATE INDEX IX_VMPricing_VMSize ON [dbo].[VMPricing](VMSizeID);
    CREATE INDEX IX_VMPricing_Region ON [dbo].[VMPricing](RegionID);
    CREATE INDEX IX_VMPricing_Model ON [dbo].[VMPricing](PricingModelID);
    CREATE INDEX IX_VMPricing_Current ON [dbo].[VMPricing](ExpiryDate) WHERE ExpiryDate IS NULL;
    CREATE INDEX IX_VMPricing_EffectiveDate ON [dbo].[VMPricing](EffectiveDate);
    CREATE INDEX IX_VMPricing_OS ON [dbo].[VMPricing](OperatingSystem);

    PRINT 'Created VMPricing table';
END
ELSE
BEGIN
    PRINT 'VMPricing table already exists';
END;

-- Add foreign keys for VMPricing
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_VMPricing_VMSizes')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMPricing' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    ALTER TABLE [dbo].[VMPricing]
    ADD CONSTRAINT FK_VMPricing_VMSizes
    FOREIGN KEY (VMSizeID) REFERENCES [dbo].[VMSizes](VMSizeID);

    PRINT 'Added FK: VMPricing.VMSizeID -> VMSizes.VMSizeID';
END;

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_VMPricing_AzureRegions')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMPricing' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    ALTER TABLE [dbo].[VMPricing]
    ADD CONSTRAINT FK_VMPricing_AzureRegions
    FOREIGN KEY (RegionID) REFERENCES [dbo].[AzureRegions](RegionID);

    PRINT 'Added FK: VMPricing.RegionID -> AzureRegions.RegionID';
END;

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_VMPricing_PricingModels')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMPricing' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    ALTER TABLE [dbo].[VMPricing]
    ADD CONSTRAINT FK_VMPricing_PricingModels
    FOREIGN KEY (PricingModelID) REFERENCES [dbo].[PricingModels](PricingModelID);

    PRINT 'Added FK: VMPricing.PricingModelID -> PricingModels.PricingModelID';
END;

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_VMPricing_Currencies')
AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMPricing' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    ALTER TABLE [dbo].[VMPricing]
    ADD CONSTRAINT FK_VMPricing_Currencies
    FOREIGN KEY (CurrencyID) REFERENCES [dbo].[Currencies](CurrencyID);

    PRINT 'Added FK: VMPricing.CurrencyID -> Currencies.CurrencyID';
END;

-- =============================================
-- PART 5: ETL/Load Tracking
-- =============================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DataLoadHistory' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[DataLoadHistory] (
        LoadID INT IDENTITY(1,1) PRIMARY KEY,
        LoadType NVARCHAR(50) NOT NULL,
        LoadStatus NVARCHAR(50) NOT NULL,
        RecordsProcessed INT NULL,
        RecordsInserted INT NULL,
        RecordsUpdated INT NULL,
        RecordsDeleted INT NULL,
        ErrorMessage NVARCHAR(MAX) NULL,
        StartTime DATETIME NOT NULL DEFAULT GETDATE(),
        EndTime DATETIME NULL,
        DurationSeconds AS DATEDIFF(SECOND, StartTime, EndTime),
        RunbookName NVARCHAR(200) NULL,
        ExecutedBy NVARCHAR(100) NULL
    );

    CREATE INDEX IX_LoadHistory_Type ON [dbo].[DataLoadHistory](LoadType);
    CREATE INDEX IX_LoadHistory_Status ON [dbo].[DataLoadHistory](LoadStatus);
    CREATE INDEX IX_LoadHistory_StartTime ON [dbo].[DataLoadHistory](StartTime);

    PRINT 'Created DataLoadHistory table';
END
ELSE
BEGIN
    PRINT 'DataLoadHistory table already exists';
END;

-- =============================================
-- PART 6: Views for Easy Querying
-- =============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_VMSizesWithPricing')
    DROP VIEW [dbo].[vw_VMSizesWithPricing];
GO

CREATE VIEW [dbo].[vw_VMSizesWithPricing]
AS
SELECT
    vm.VMSizeID,
    vm.VMSizeName,
    fam.FamilyCode,
    fam.FamilyName,
    vm.vCPUs,
    vm.MemoryGB,
    vm.TempStorageGB,
    vm.MaxDataDisks,
    vm.MaxNICs,
    vm.AcceleratedNetworkingEnabled,
    vm.PremiumIOSupported,
    vm.EphemeralOSDiskSupported,
    reg.RegionName,
    reg.DisplayName AS RegionDisplayName,
    reg.Geography,
    pricing.PricePerHour AS LinuxPricePerHour,
    pricing.PricePerMonth AS LinuxPricePerMonth,
    pricing.CurrencyCode,
    pricing.CurrencySymbol,
    pricing.PricePerMonth * 12 AS EstimatedAnnualCost,
    CASE WHEN vm.vCPUs > 0 THEN pricing.PricePerMonth / vm.vCPUs ELSE 0 END AS PricePerCPU,
    CASE WHEN vm.MemoryGB > 0 THEN pricing.PricePerMonth / vm.MemoryGB ELSE 0 END AS PricePerGB,
    vm.CreatedDate,
    vm.UpdatedDate
FROM
    [dbo].[VMSizes] vm
    LEFT JOIN [dbo].[VMFamilies] fam ON vm.FamilyID = fam.FamilyID
    LEFT JOIN [dbo].[VMSizeRegionalAvailability] avail ON vm.VMSizeID = avail.VMSizeID
    LEFT JOIN [dbo].[AzureRegions] reg ON avail.RegionID = reg.RegionID
    LEFT JOIN (
        SELECT
            p.VMSizeID,
            p.RegionID,
            p.PricePerHour,
            p.PricePerMonth,
            c.CurrencyCode,
            c.Symbol AS CurrencySymbol
        FROM [dbo].[VMPricing] p
        INNER JOIN [dbo].[Currencies] c ON p.CurrencyID = c.CurrencyID
        INNER JOIN [dbo].[PricingModels] pm ON p.PricingModelID = pm.PricingModelID
        WHERE
            p.ExpiryDate IS NULL
            AND p.OperatingSystem = 'Linux'
            AND pm.ModelCode = 'PayAsYouGo'
    ) pricing ON vm.VMSizeID = pricing.VMSizeID AND avail.RegionID = pricing.RegionID
WHERE
    vm.IsActive = 1
    AND (avail.IsAvailable = 1 OR avail.IsAvailable IS NULL);
GO

PRINT 'Created view: vw_VMSizesWithPricing';

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_PriceComparisonByRegion')
    DROP VIEW [dbo].[vw_PriceComparisonByRegion];
GO

CREATE VIEW [dbo].[vw_PriceComparisonByRegion]
AS
SELECT
    vm.VMSizeName,
    vm.vCPUs,
    vm.MemoryGB,
    reg.RegionName,
    reg.Geography,
    p.PricePerMonth,
    p.OperatingSystem,
    pm.ModelName AS PricingModel,
    c.CurrencyCode,
    p.EffectiveDate
FROM
    [dbo].[VMPricing] p
    INNER JOIN [dbo].[VMSizes] vm ON p.VMSizeID = vm.VMSizeID
    INNER JOIN [dbo].[AzureRegions] reg ON p.RegionID = reg.RegionID
    INNER JOIN [dbo].[PricingModels] pm ON p.PricingModelID = pm.PricingModelID
    INNER JOIN [dbo].[Currencies] c ON p.CurrencyID = c.CurrencyID
WHERE
    p.ExpiryDate IS NULL;
GO

PRINT 'Created view: vw_PriceComparisonByRegion';

-- =============================================
-- PART 7: Stored Procedures
-- =============================================

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_UpsertVMSize')
    DROP PROCEDURE [dbo].[usp_UpsertVMSize];
GO

CREATE PROCEDURE [dbo].[usp_UpsertVMSize]
    @VMSizeName NVARCHAR(100),
    @FamilyCode NCHAR(1),
    @vCPUs INT,
    @MemoryGB DECIMAL(10,2),
    @TempStorageGB INT = NULL,
    @MaxDataDisks INT,
    @MaxNICs INT,
    @AcceleratedNetworkingEnabled BIT = 0,
    @PremiumIOSupported BIT = 0,
    @EphemeralOSDiskSupported BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FamilyID INT;
    DECLARE @VMSizeID INT;

    SELECT @FamilyID = FamilyID FROM [dbo].[VMFamilies] WHERE FamilyCode = @FamilyCode;
    SELECT @VMSizeID = VMSizeID FROM [dbo].[VMSizes] WHERE VMSizeName = @VMSizeName;

    IF @VMSizeID IS NULL
    BEGIN
        INSERT INTO [dbo].[VMSizes] (
            VMSizeName, FamilyID, vCPUs, MemoryGB, TempStorageGB,
            MaxDataDisks, MaxNICs, AcceleratedNetworkingEnabled,
            PremiumIOSupported, EphemeralOSDiskSupported
        )
        VALUES (
            @VMSizeName, @FamilyID, @vCPUs, @MemoryGB, @TempStorageGB,
            @MaxDataDisks, @MaxNICs, @AcceleratedNetworkingEnabled,
            @PremiumIOSupported, @EphemeralOSDiskSupported
        );
        SET @VMSizeID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE [dbo].[VMSizes]
        SET
            FamilyID = @FamilyID,
            vCPUs = @vCPUs,
            MemoryGB = @MemoryGB,
            TempStorageGB = @TempStorageGB,
            MaxDataDisks = @MaxDataDisks,
            MaxNICs = @MaxNICs,
            AcceleratedNetworkingEnabled = @AcceleratedNetworkingEnabled,
            PremiumIOSupported = @PremiumIOSupported,
            EphemeralOSDiskSupported = @EphemeralOSDiskSupported,
            UpdatedDate = GETDATE()
        WHERE VMSizeID = @VMSizeID;
    END

    RETURN @VMSizeID;
END;
GO

PRINT 'Created SP: usp_UpsertVMSize';

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_UpsertVMPricing')
    DROP PROCEDURE [dbo].[usp_UpsertVMPricing];
GO

CREATE PROCEDURE [dbo].[usp_UpsertVMPricing]
    @VMSizeName NVARCHAR(100),
    @RegionName NVARCHAR(100),
    @PricingModelCode NVARCHAR(50),
    @CurrencyCode NCHAR(3),
    @OperatingSystem NVARCHAR(50),
    @PricePerHour DECIMAL(18,6),
    @MeterID NVARCHAR(100) = NULL,
    @ProductName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @VMSizeID INT;
    DECLARE @RegionID INT;
    DECLARE @PricingModelID INT;
    DECLARE @CurrencyID INT;
    DECLARE @PricePerMonth DECIMAL(18,2);

    SET @PricePerMonth = @PricePerHour * 730;

    SELECT @VMSizeID = VMSizeID FROM [dbo].[VMSizes] WHERE VMSizeName = @VMSizeName;
    SELECT @RegionID = RegionID FROM [dbo].[AzureRegions] WHERE RegionName = @RegionName;
    SELECT @PricingModelID = PricingModelID FROM [dbo].[PricingModels] WHERE ModelCode = @PricingModelCode;
    SELECT @CurrencyID = CurrencyID FROM [dbo].[Currencies] WHERE CurrencyCode = @CurrencyCode;

    IF @VMSizeID IS NULL OR @RegionID IS NULL OR @PricingModelID IS NULL OR @CurrencyID IS NULL
    BEGIN
        RAISERROR('Invalid foreign key reference', 16, 1);
        RETURN -1;
    END;

    UPDATE [dbo].[VMPricing]
    SET ExpiryDate = GETDATE()
    WHERE
        VMSizeID = @VMSizeID
        AND RegionID = @RegionID
        AND PricingModelID = @PricingModelID
        AND OperatingSystem = @OperatingSystem
        AND ExpiryDate IS NULL;

    INSERT INTO [dbo].[VMPricing] (
        VMSizeID, RegionID, PricingModelID, CurrencyID,
        PricePerHour, PricePerMonth, OperatingSystem,
        MeterID, ProductName, EffectiveDate
    )
    VALUES (
        @VMSizeID, @RegionID, @PricingModelID, @CurrencyID,
        @PricePerHour, @PricePerMonth, @OperatingSystem,
        @MeterID, @ProductName, GETDATE()
    );

    RETURN 0;
END;
GO

PRINT 'Created SP: usp_UpsertVMPricing';

PRINT '============================================';
PRINT 'Schema upgrade completed successfully!';
PRINT '============================================';
PRINT 'Tables: AzureRegions, VMFamilies, PricingModels,';
PRINT '        Currencies, VMSizes, VMSizeRegionalAvailability,';
PRINT '        VMPricing, DataLoadHistory';
PRINT 'Views: vw_VMSizesWithPricing, vw_PriceComparisonByRegion';
PRINT 'SPs: usp_UpsertVMSize, usp_UpsertVMPricing';
PRINT '============================================';
