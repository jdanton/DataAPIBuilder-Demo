# Database Schema Upgrade Guide
## Version 2.0 - Adding Azure Pricing Data

## Overview

This guide walks through upgrading the VMSizes database to version 2.0, which includes:
- Cleaned up and normalized schema
- Azure VM pricing data integration
- Regional availability tracking
- Historical pricing support
- Enhanced views for cost analysis

## What's New in V2.0

### New Tables

1. **VMFamilies** - Reference table for VM family classifications (A, B, D, E, F, etc.)
2. **VMPricing** - Stores VM pricing data with historical tracking
3. **PricingModels** - Defines pricing types (Pay-As-You-Go, Reserved, Spot)
4. **Currencies** - Multi-currency support (USD, EUR, GBP, etc.)
5. **VMSizeRegionalAvailability** - Tracks which VMs are available in which regions
6. **DataLoadHistory** - Comprehensive ETL tracking (replaces loadStatus)

### Cleaned Up Schema

- **VMSizes** table now normalized with proper foreign keys
- Removed temporary/staging tables from production schema
- Added proper indexes for performance
- Enhanced metadata tracking

### New Views

1. **vw_VMSizesWithPricing** - Complete VM info with current Linux pricing
2. **vw_PriceComparisonByRegion** - Compare pricing across regions

### New Stored Procedures

1. **usp_UpsertVMSize** - Insert or update VM size data
2. **usp_UpsertVMPricing** - Insert or update pricing with history

## Schema Changes

### Before (V1.0)
```
vmsizes (flat table with limited attributes)
VMSizesTemp (staging)
VMsJSON (raw data)
AzureRegions (basic)
```

### After (V2.0)
```
VMSizes (normalized with FamilyID foreign key)
  ├── VMFamilies (reference)
  └── VMSizeRegionalAvailability
      └── AzureRegions (enhanced)

VMPricing (historical pricing)
  ├── VMSizes (foreign key)
  ├── AzureRegions (foreign key)
  ├── PricingModels (foreign key)
  └── Currencies (foreign key)

DataLoadHistory (ETL tracking)
```

## Deployment Steps

### Step 1: Backup Existing Database

**CRITICAL**: Always backup before making schema changes!

```bash
# Export existing database to DACPAC
sqlpackage /Action:Extract \
  /SourceServerName:dataapibuilderdemo.database.windows.net \
  /SourceDatabaseName:VMSizes \
  /TargetFile:VMSizes-backup-$(date +%Y%m%d).dacpac \
  /AccessToken:"$(az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv)"

# Or use Azure CLI
az sql db export \
  --resource-group DataAPIBuilder \
  --server dataapibuilderdemo \
  --name VMSizes \
  --admin-user <admin> \
  --admin-password <password> \
  --storage-key-type StorageAccessKey \
  --storage-key <key> \
  --storage-uri https://<storage>.blob.core.windows.net/backups/vmsizes-backup.bacpac
```

### Step 2: Run Schema Upgrade Script

```bash
# Connect to SQL Database and run the upgrade script
sqlcmd -S dataapibuilderdemo.database.windows.net \
  -d VMSizes \
  -G \
  -i sql/schema-cleanup-and-pricing.sql
```

Or use Azure Data Studio / SSMS to execute `schema-cleanup-and-pricing.sql`

### Step 3: Migrate Existing Data (if applicable)

If you have existing data in the old `vmsizes` table, migrate it:

```sql
-- This script should be run AFTER the schema upgrade

-- Migrate existing VM sizes to new schema
INSERT INTO VMSizes (
    VMSizeName, FamilyID, vCPUs, MemoryGB, MaxDataDisks, MaxNICs,
    AcceleratedNetworkingEnabled, EphemeralOSDiskSupported
)
SELECT DISTINCT
    Name,
    (SELECT FamilyID FROM VMFamilies WHERE FamilyCode = LEFT(Name, 1)),
    CPU,
    MemoryGB,
    MaxDisks,
    MaxNICS,
    CASE WHEN AcceleratedNetworking = 'True' THEN 1 ELSE 0 END,
    CASE WHEN EphemeralOSDiskSupported = 'True' THEN 1 ELSE 0 END
FROM dbo.vmsizes_old -- rename your old table first
WHERE Name IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM VMSizes WHERE VMSizeName = Name);

-- Migrate regional availability
INSERT INTO VMSizeRegionalAvailability (VMSizeID, RegionID, IsAvailable)
SELECT DISTINCT
    vm.VMSizeID,
    reg.RegionID,
    1
FROM dbo.vmsizes_old old
INNER JOIN VMSizes vm ON vm.VMSizeName = old.Name
INNER JOIN AzureRegions reg ON reg.RegionName = old.Region;
```

### Step 4: Deploy Updated Runbooks

Upload the new runbooks to Azure Automation:

```bash
# Upload GetData-v2.ps1
az automation runbook create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData-v2 \
  --type PowerShell72 \
  --location eastus

az automation runbook replace-content \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData-v2 \
  --content @runbooks/GetData-v2.ps1

az automation runbook publish \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData-v2

# Upload GetPricingData.ps1
az automation runbook create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetPricingData \
  --type PowerShell72 \
  --location eastus

az automation runbook replace-content \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetPricingData \
  --content @runbooks/GetPricingData.ps1

az automation runbook publish \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetPricingData
```

### Step 5: Run Initial Data Collection

```bash
# Run the VM data collection runbook
az automation runbook start \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData-v2

# Wait for it to complete, then run pricing collection
az automation runbook start \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetPricingData
```

### Step 6: Update Data API Builder Configuration

```bash
# Update the configuration file
cp dab-config-with-pricing.json /path/to/your/app/dab-config.json

# If using containers, rebuild and redeploy
docker build -f Dockerfile.alternative \
  -t dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:v2 .

docker push dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:v2

# Update App Service
az webapp config container set \
  --resource-group DataAPIBuilder \
  --name vmsizesazure \
  --docker-custom-image-name dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:v2

az webapp restart \
  --resource-group DataAPIBuilder \
  --name vmsizesazure
```

### Step 7: Schedule Automated Runs

```bash
# Schedule VM data collection (daily at 2 AM)
az automation schedule create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name DailyVMDataCollection \
  --frequency Day \
  --interval 1 \
  --start-time "2026-02-17T02:00:00+00:00" \
  --time-zone "UTC"

az automation job-schedule create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --runbook-name GetData-v2 \
  --schedule-name DailyVMDataCollection

# Schedule pricing data collection (weekly on Sunday at 3 AM)
az automation schedule create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name WeeklyPricingCollection \
  --frequency Week \
  --interval 1 \
  --start-time "2026-02-17T03:00:00+00:00" \
  --time-zone "UTC"

az automation job-schedule create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --runbook-name GetPricingData \
  --schedule-name WeeklyPricingCollection
```

## New API Endpoints

After upgrading, these new endpoints will be available:

### REST API

```bash
# Get all VM sizes with pricing
GET /api/vmsizes-pricing

# Filter by region
GET /api/vmsizes-pricing?$filter=RegionName eq 'eastus'

# Filter by CPU and memory
GET /api/vmsizes-pricing?$filter=vCPUs ge 4 and MemoryGB ge 16

# Filter by price
GET /api/vmsizes-pricing?$filter=LinuxPricePerMonth lt 200

# Get regions
GET /api/regions

# Get VM families
GET /api/families

# Get pricing data
GET /api/pricing

# Price comparison across regions
GET /api/price-comparison?$filter=VMSizeName eq 'Standard_D4s_v3'
```

### GraphQL API

```graphql
# Query VMs with pricing
query {
  vmsizesWithPricing(
    filter: {
      regionName: { eq: "eastus" }
      vCPUs: { ge: 4 }
      linuxPricePerMonth: { lt: 200 }
    }
    orderBy: { linuxPricePerMonth: ASC }
  ) {
    items {
      vmSizeName
      familyName
      vCPUs
      memoryGB
      regionName
      linuxPricePerHour
      linuxPricePerMonth
      estimatedAnnualCost
      pricePerCPU
      pricePerGB
    }
  }
}

# Get pricing comparison
query {
  priceComparisons(
    filter: { vmSizeName: { eq: "Standard_D4s_v3" } }
    orderBy: { pricePerMonth: ASC }
  ) {
    items {
      regionName
      geography
      pricePerMonth
      operatingSystem
      pricingModel
    }
  }
}

# Get VM families
query {
  vmFamilies {
    items {
      familyCode
      familyName
      description
      useCase
    }
  }
}
```

## Example Queries

### Find cheapest VMs with specific specs

```sql
-- Find cheapest 4-CPU, 16GB VMs across all regions
SELECT TOP 10
    VMSizeName,
    RegionName,
    vCPUs,
    MemoryGB,
    LinuxPricePerMonth,
    EstimatedAnnualCost
FROM vw_VMSizesWithPricing
WHERE vCPUs = 4 AND MemoryGB >= 16
ORDER BY LinuxPricePerMonth ASC;
```

### Compare pricing across regions

```sql
-- Compare Standard_D4s_v3 pricing across regions
SELECT
    RegionName,
    Geography,
    PricePerMonth,
    OperatingSystem
FROM vw_PriceComparisonByRegion
WHERE VMSizeName = 'Standard_D4s_v3'
  AND OperatingSystem = 'Linux'
ORDER BY PricePerMonth ASC;
```

### Price per performance analysis

```sql
-- Find best value VMs (lowest price per vCPU)
SELECT TOP 20
    VMSizeName,
    RegionName,
    vCPUs,
    MemoryGB,
    LinuxPricePerMonth,
    PricePerCPU
FROM vw_VMSizesWithPricing
WHERE PricePerCPU IS NOT NULL
ORDER BY PricePerCPU ASC;
```

## Rollback Plan

If issues arise, you can rollback:

```bash
# Restore from DACPAC backup
sqlpackage /Action:Publish \
  /SourceFile:VMSizes-backup-YYYYMMDD.dacpac \
  /TargetServerName:dataapibuilderdemo.database.windows.net \
  /TargetDatabaseName:VMSizes \
  /AccessToken:"$(az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv)"

# Revert runbooks
az automation runbook publish \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData

# Revert Data API Builder config
cp dab-config.json.backup dab-config.json
# Redeploy container
```

## Testing

After deployment, test the new endpoints:

```bash
# Test basic VM query
curl https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing | jq '.[0]'

# Test pricing endpoint
curl https://vmsizesazure.azurewebsites.net/api/pricing | jq '.[]| select(.OperatingSystem == "Linux") | .PricePerHour' | head -5

# Test GraphQL
curl -X POST https://vmsizesazure.azurewebsites.net/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ vmsizesWithPricing(first: 5) { items { vmSizeName linuxPricePerMonth } } }"}'
```

## Monitoring

Monitor the data loads:

```sql
-- Check recent data loads
SELECT TOP 10
    LoadType,
    LoadStatus,
    RecordsProcessed,
    StartTime,
    EndTime,
    DurationSeconds,
    ErrorMessage
FROM DataLoadHistory
ORDER BY StartTime DESC;

-- Check pricing data freshness
SELECT
    MIN(EffectiveDate) AS OldestPrice,
    MAX(EffectiveDate) AS NewestPrice,
    COUNT(*) AS TotalPrices,
    COUNT(DISTINCT VMSizeID) AS VMsWithPricing
FROM VMPricing
WHERE ExpiryDate IS NULL;
```

## Troubleshooting

### Issue: Runbook fails with "Invalid foreign key"

**Solution**: Ensure all reference data is populated first:
```sql
-- Verify regions exist
SELECT COUNT(*) FROM AzureRegions;

-- Verify families exist
SELECT COUNT(*) FROM VMFamilies;

-- Verify currencies exist
SELECT COUNT(*) FROM Currencies;
```

### Issue: No pricing data appears

**Solution**: Check the GetPricingData runbook output and verify Azure Retail Prices API access:
```powershell
# Test API access manually
Invoke-RestMethod -Uri 'https://prices.azure.com/api/retail/prices?$filter=serviceName eq ''Virtual Machines''' | ConvertTo-Json
```

### Issue: Data API Builder shows 500 errors

**Solution**: Check views exist and Data API Builder configuration is valid:
```bash
# Verify views
sqlcmd -S dataapibuilderdemo.database.windows.net -d VMSizes -G \
  -Q "SELECT name FROM sys.views WHERE name LIKE 'vw_%'"

# Validate DAB config
dab validate --config dab-config-with-pricing.json
```

## Support

For issues or questions:
- Review DataLoadHistory table for ETL errors
- Check Azure Automation job output
- Review App Service logs: `az webapp log tail --name vmsizesazure --resource-group DataAPIBuilder`

## Next Steps

1. Set up monitoring alerts for failed data loads
2. Configure backup retention policies
3. Add more pricing models (Reserved Instances, Spot)
4. Implement caching strategy in Data API Builder
5. Create Power BI dashboards for cost analysis
