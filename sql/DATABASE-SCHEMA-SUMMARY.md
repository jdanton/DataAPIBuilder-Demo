# VMSizes Database Schema Summary

## Overview
This document summarizes the database schema extracted from the Azure SQL Database using sqlpackage.

**Source**: DataAPIBuilder Resource Group > dataapibuilderdemo SQL Server > VMSizes Database
**Extracted**: 2026-02-16
**Method**: sqlpackage /Action:Extract to DACPAC format

## Files Generated

| File | Description | Size |
|------|-------------|------|
| `VMSizes.dacpac` | Complete database package (schema + metadata) | 43 KB |
| `model.xml` | Full schema model extracted from DACPAC | 463 KB |
| `VMSizes-extracted-schema.sql` | Auto-generated CREATE TABLE statements | - |
| `extract-full-schema.py` | Python script to parse model.xml | - |

## Database Objects

### Tables (8 total)

1. **[dbo].[vmsizes]** - Main table for VM size data
   - Primary table used by Data API Builder
   - Contains VM SKU information (CPU, Memory, IOPS, etc.)
   - Data populated by GetData automation runbook

2. **[dbo].[vmsizes_CCI]** - Columnstore clustered index version
   - Optimized for analytical queries
   - Same structure as vmsizes but with columnstore index

3. **[dbo].[VMSizesTemp]** - Temporary staging table
   - Used during data load operations
   - Likely used by runbooks for bulk insert

4. **[dbo].[VMsJSON]** - JSON format storage
   - Stores raw JSON data from Azure API
   - May contain unprocessed VM information

5. **[dbo].[AzureRegions]** - Azure region reference table
   - Lookup table for region information
   - Used for data validation and filtering

6. **[dbo].[Systems]** - System configuration table
   - Application metadata and settings
   - May track deployment information

7. **[dbo].[Users]** - User management table
   - Demo/presentation user accounts
   - Access control for the application

8. **[dbo].[loadStatus]** - ETL tracking table
   - Tracks data load operations
   - Monitors runbook execution status

### Views (1 total)

1. **[dbo].[DemoView]** - Presentation/demo view
   - Simplified view for demos
   - May join multiple tables for reporting

### Stored Procedures (4 total)

1. **[dbo].[PopulateVMs]** - Main data population procedure
   - Likely called by automation runbooks
   - Handles bulk data insert/update operations

2. **[dbo].[CursorPopulateVMs]** - Cursor-based population
   - Alternative/legacy data load method
   - Row-by-row processing (slower but more controlled)

3. **[dbo].[sp_WhoIsActive]** - Monitoring procedure
   - Famous Adam Machanic procedure for SQL monitoring
   - Used to troubleshoot performance issues
   - See: https://whoisactive.com

4. **[dbo].[usp_demo]** - Demo stored procedure
   - Custom procedure for presentations
   - May contain example queries or data manipulation

### Security Objects

1. **Database Credential: BlobStorageC**
   - Identity: `Managed Service Identity`
   - Used for connecting to Azure Blob Storage
   - Enables OPENROWSET or BULK INSERT from blobs

2. **Role Membership**
   - **VMSizesLogicApp**: Member of `db_datawriter`
   - Allows Logic App to write data to tables

### Database Options

- **Collation**: SQL_Latin1_General_CP1_CI_AS
- **Encryption**: Enabled (Transparent Data Encryption)
- **Snapshot Isolation**: Enabled
- **Read Committed Snapshot**: Enabled
- **Full Text Search**: Enabled
- **Recovery Target**: 120 seconds

## Expected Schema (vmsizes table)

Based on the GetData runbook analysis, the main `vmsizes` table likely contains:

```sql
CREATE TABLE [dbo].[vmsizes] (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    CPU INT,
    MemoryGB DECIMAL(10,2),
    IOPS INT,
    MaxNICS INT,
    MaxDisks INT,
    AcceleratedNetworking NVARCHAR(10),
    EphemeralOSDiskSupported NVARCHAR(10),
    Region NVARCHAR(50) NOT NULL,
    CreatedDate DATETIME DEFAULT GETDATE(),
    UpdatedDate DATETIME DEFAULT GETDATE()
);
```

## Data Flow

```
Azure Automation (GetData)
    ↓
Blob Storage (JSON files)
    ↓
OPENROWSET / BULK INSERT (using BlobStorageC credential)
    ↓
VMsJSON or VMSizesTemp (staging)
    ↓
PopulateVMs / CursorPopulateVMs (stored procedures)
    ↓
vmsizes (main table)
    ↓
vmsizes_CCI (columnstore for analytics)
    ↓
Data API Builder
```

## Access Patterns

### Data API Builder
- **Primary Table**: vmsizes
- **Read Operations**: REST API queries, GraphQL queries
- **Typical Queries**:
  - Filter by region
  - Filter by CPU/Memory requirements
  - Search by VM name
  - Sort by various capabilities

### Logic App
- **Write Access**: All tables (db_datawriter role)
- **Operations**: Insert, Update, Delete
- **Likely Usage**: Data synchronization, cleanup tasks

### Automation Runbooks
- **Via Stored Procedures**: PopulateVMs, CursorPopulateVMs
- **Direct Blob Integration**: BlobStorageC credential
- **Operations**: Bulk data loads, ETL processing

## Performance Considerations

### Indexing Strategy
- Primary keys on all tables (ID columns)
- vmsizes_CCI uses columnstore for analytical queries
- Additional indexes may exist (check model.xml for details)

### Table Partitioning
- Not evident from DACPAC
- May be implemented on larger tables

### Optimization for Data API Builder
- Consider indexes on:
  - Region (for regional filtering)
  - Name (for VM name searches)
  - CPU, MemoryGB (for specification searches)
  - AcceleratedNetworking, EphemeralOSDiskSupported (for feature filtering)

## Recommendations

### For Complete Schema Export

To get the full DDL with all details, use one of these methods:

#### Option 1: SQL Server Management Studio (SSMS)
1. Connect to dataapibuilderdemo.database.windows.net
2. Right-click VMSizes database
3. Tasks → Generate Scripts
4. Select all objects
5. Set scripting options (include indexes, constraints, etc.)

#### Option 2: Azure Data Studio
1. Connect to the database
2. Right-click database → Script as CREATE
3. Export to file

#### Option 3: mssql-scripter (CLI)
```bash
mssql-scripter -S dataapibuilderdemo.database.windows.net \
  -d VMSizes \
  -U username \
  --schema-and-data \
  > complete-schema.sql
```

#### Option 4: Use the DACPAC
```bash
# The VMSizes.dacpac file IS the complete schema
# Import it to any SQL Server to recreate the database:
sqlpackage /Action:Publish \
  /SourceFile:VMSizes.dacpac \
  /TargetServerName:your-server \
  /TargetDatabaseName:VMSizes
```

### Data API Builder Configuration

Update `dab-config.json` to include all relevant tables:
- vmsizes (primary)
- AzureRegions (lookup)
- vmsizes_CCI (for analytics endpoints)
- DemoView (simplified queries)

## Next Steps

1. **Document Exact Schema**:
   - Connect to database and script out complete DDL
   - Document all indexes, constraints, and triggers

2. **Optimize Data API Builder Config**:
   - Map all columns in vmsizes table
   - Add proper field mappings
   - Configure permissions and authorization

3. **Add Additional Entities**:
   - Expose AzureRegions for region lookups
   - Create API endpoint for DemoView
   - Consider exposing loadStatus for monitoring

4. **Performance Testing**:
   - Test query performance with indexes
   - Compare vmsizes vs vmsizes_CCI performance
   - Optimize Data API Builder caching

## Resources

- **DACPAC Location**: `sql/VMSizes.dacpac`
- **Model XML**: `sql/model.xml`
- **Adam Machanic's sp_WhoIsActive**: https://whoisactive.com
- **DACPAC Documentation**: https://learn.microsoft.com/sql/relational-databases/data-tier-applications/data-tier-applications
- **sqlpackage CLI**: https://learn.microsoft.com/sql/tools/sqlpackage/sqlpackage
