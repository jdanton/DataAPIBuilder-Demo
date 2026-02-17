-- VMSizes Database Schema
-- This schema matches the data collected by the GetData runbook

USE master;
GO

-- Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'VMSizes')
BEGIN
    CREATE DATABASE VMSizes;
END
GO

USE VMSizes;
GO

-- Create VMSizes table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizes')
BEGIN
    CREATE TABLE dbo.VMSizes (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(100) NOT NULL,
        CPU INT NULL,
        MemoryGB DECIMAL(10,2) NULL,
        IOPS INT NULL,
        MaxNICS INT NULL,
        MaxDisks INT NULL,
        AcceleratedNetworking NVARCHAR(10) NULL,
        EphemeralOSDiskSupported NVARCHAR(10) NULL,
        Region NVARCHAR(50) NOT NULL,
        CreatedDate DATETIME DEFAULT GETDATE(),
        UpdatedDate DATETIME DEFAULT GETDATE(),

        -- Index for common queries
        INDEX IX_VMSizes_Region (Region),
        INDEX IX_VMSizes_Name (Name),
        INDEX IX_VMSizes_CPU_Memory (CPU, MemoryGB)
    );
END
GO

-- Create a view for easier querying
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_VMSizes')
BEGIN
    DROP VIEW dbo.vw_VMSizes;
END
GO

CREATE VIEW dbo.vw_VMSizes
AS
SELECT
    Id,
    Name,
    CPU,
    MemoryGB,
    IOPS,
    MaxNICS,
    MaxDisks,
    CASE
        WHEN AcceleratedNetworking = 'True' THEN 1
        ELSE 0
    END AS AcceleratedNetworkingEnabled,
    CASE
        WHEN EphemeralOSDiskSupported = 'True' THEN 1
        ELSE 0
    END AS EphemeralOSDiskEnabled,
    Region,
    CreatedDate,
    UpdatedDate
FROM dbo.VMSizes;
GO

-- Stored procedure to insert or update VM sizes
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'usp_UpsertVMSize')
BEGIN
    DROP PROCEDURE dbo.usp_UpsertVMSize;
END
GO

CREATE PROCEDURE dbo.usp_UpsertVMSize
    @Name NVARCHAR(100),
    @CPU INT,
    @MemoryGB DECIMAL(10,2),
    @IOPS INT,
    @MaxNICS INT,
    @MaxDisks INT,
    @AcceleratedNetworking NVARCHAR(10),
    @EphemeralOSDiskSupported NVARCHAR(10),
    @Region NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if record exists
    IF EXISTS (SELECT 1 FROM dbo.VMSizes WHERE Name = @Name AND Region = @Region)
    BEGIN
        -- Update existing record
        UPDATE dbo.VMSizes
        SET
            CPU = @CPU,
            MemoryGB = @MemoryGB,
            IOPS = @IOPS,
            MaxNICS = @MaxNICS,
            MaxDisks = @MaxDisks,
            AcceleratedNetworking = @AcceleratedNetworking,
            EphemeralOSDiskSupported = @EphemeralOSDiskSupported,
            UpdatedDate = GETDATE()
        WHERE Name = @Name AND Region = @Region;
    END
    ELSE
    BEGIN
        -- Insert new record
        INSERT INTO dbo.VMSizes (
            Name,
            CPU,
            MemoryGB,
            IOPS,
            MaxNICS,
            MaxDisks,
            AcceleratedNetworking,
            EphemeralOSDiskSupported,
            Region
        )
        VALUES (
            @Name,
            @CPU,
            @MemoryGB,
            @IOPS,
            @MaxNICS,
            @MaxDisks,
            @AcceleratedNetworking,
            @EphemeralOSDiskSupported,
            @Region
        );
    END
END
GO

-- Sample data for testing (optional)
-- Uncomment to insert sample data

/*
INSERT INTO dbo.VMSizes (Name, CPU, MemoryGB, IOPS, MaxNICS, MaxDisks, AcceleratedNetworking, EphemeralOSDiskSupported, Region)
VALUES
    ('Standard_D2s_v3', 2, 8, 3200, 2, 4, 'True', 'True', 'eastus'),
    ('Standard_D4s_v3', 4, 16, 6400, 2, 8, 'True', 'True', 'eastus'),
    ('Standard_D8s_v3', 8, 32, 12800, 4, 16, 'True', 'True', 'eastus'),
    ('Standard_E2s_v3', 2, 16, 3200, 2, 4, 'True', 'False', 'westus2'),
    ('Standard_E4s_v3', 4, 32, 6400, 2, 8, 'True', 'False', 'westus2'),
    ('Standard_F2s_v2', 2, 4, 3200, 2, 4, 'True', 'True', 'westeurope'),
    ('Standard_F4s_v2', 4, 8, 6400, 2, 8, 'True', 'True', 'westeurope');
*/

-- Grant permissions for Data API Builder
-- Uncomment and adjust username as needed
/*
CREATE USER [DataAPIBuilderUser] WITH PASSWORD = 'YourStrongPassword123!';
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.VMSizes TO [DataAPIBuilderUser];
GRANT EXECUTE ON dbo.usp_UpsertVMSize TO [DataAPIBuilderUser];
*/

PRINT 'Database schema created successfully';
GO
