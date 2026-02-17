# Quick Fix: Schema Upgrade Authentication Issue

## Problem
sqlcmd's `-G` (Azure AD Integrated Auth) flag doesn't work reliably on macOS.

## Solution Options

### Option 1: Use Azure Portal (Easiest) ✅

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to: **SQL databases** → **VMSizes** → **Query editor**
3. Click **Login** (will use your Azure AD credentials)
4. Copy and paste the contents of `sql/schema-cleanup-and-pricing.sql`
5. Click **Run**

This is the **most reliable** method.

### Option 2: Use Azure Data Studio ✅

```bash
# Install Azure Data Studio
brew install --cask azure-data-studio

# Open it and connect to:
Server: dataapibuilderdemo.database.windows.net
Authentication: Azure Active Directory
Database: VMSizes

# Then open and execute: sql/schema-cleanup-and-pricing.sql
```

### Option 3: Fix the Deployment Script

Edit `deploy-pricing-upgrade.sh` line 311, change from:

```bash
if sqlcmd -S "${SQL_SERVER}.database.windows.net" \
    -d "${DATABASE}" \
    -G \
    -i "${schema_file}" \
```

To:

```bash
# Get access token
TOKEN=$(az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv)

if sqlcmd -S "${SQL_SERVER}.database.windows.net" \
    -d "${DATABASE}" \
    -U "token" \
    -P "${TOKEN}" \
    -i "${schema_file}" \
```

**Note**: Even this may not work on all systems. Azure Portal is most reliable.

### Option 4: Use Azure CLI Direct Execution

For smaller SQL scripts, you can use:

```bash
az sql db execute \
  --server dataapibuilderdemo \
  --database VMSizes \
  --query-text "$(cat sql/schema-cleanup-and-pricing.sql)"
```

**Warning**: This may timeout for large scripts.

### Option 5: Execute in Chunks (Manual)

Break the SQL file into sections and run each:

```bash
# Section 1: Create dimension tables
az sql db execute --server dataapibuilderdemo --database VMSizes \
  --query-text "
-- Copy just the AzureRegions table creation here
CREATE TABLE [dbo].[AzureRegions] (...)
"

# Section 2: Create main tables
# ...etc
```

## Recommended: Azure Portal Method

Since you're already logged in, the fastest way is:

1. **Open**: https://portal.azure.com
2. **Navigate**: VMSizes database → Query editor
3. **Open file**: `sql/schema-cleanup-and-pricing.sql`
4. **Copy entire contents** and paste into Query editor
5. **Click Run**

The schema will be created in ~10-30 seconds.

## After Schema is Upgraded

Continue the deployment with:

```bash
./deploy-pricing-upgrade.sh
```

The script will detect the schema is already upgraded and continue with the remaining steps.

Or manually continue:

```bash
# Upload runbooks
az automation runbook create --name GetData-v2 ...

# Run data collection
az automation runbook start --name GetData-v2 ...

# etc.
```

## Why This Happens

sqlcmd's Azure AD authentication uses different mechanisms on different OS:
- **Windows**: Uses ADAL/MSAL with Windows integrated auth ✓
- **Linux**: Uses ODBC drivers with limited AD support ⚠️
- **macOS**: Often fails with credential errors ✗

Azure Portal and Azure Data Studio use REST APIs with proper OAuth tokens, so they're more reliable.

## Prevention

For future deployments, use Azure DevOps Pipelines or GitHub Actions which have proper service principal authentication.
