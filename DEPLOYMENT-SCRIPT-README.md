# Automated Deployment Script

## Overview

The `deploy-pricing-upgrade.sh` script automates the complete deployment of the schema cleanup and pricing integration features.

## Features

✅ **Automated Deployment**: One command to deploy everything
✅ **Safety Checks**: Validates prerequisites before starting
✅ **Database Backup**: Automatic DACPAC backup before changes
✅ **Error Handling**: Rolls back on failure with clear instructions
✅ **Interactive**: Prompts for confirmation at key steps
✅ **Comprehensive Logging**: Detailed logs for troubleshooting
✅ **Idempotent**: Can be run multiple times safely

## Quick Start

```bash
# Make executable
chmod +x deploy-pricing-upgrade.sh

# Run deployment
./deploy-pricing-upgrade.sh
```

## What It Does

### Automated Steps

1. **✓ Prerequisites Check**
   - Azure CLI installed and authenticated
   - sqlpackage installed (for backup)
   - sqlcmd installed (for SQL execution)
   - Docker installed (for container deployment)
   - Azure permissions validated

2. **✓ Database Backup**
   - Creates DACPAC backup in `./backups/`
   - Saves backup location for rollback

3. **✓ Schema Upgrade**
   - Runs `schema-cleanup-and-pricing.sql`
   - Creates new tables, views, procedures
   - Adds indexes for performance

4. **✓ Runbook Upload**
   - Uploads `GetData-v2.ps1`
   - Uploads `GetPricingData.ps1`
   - Publishes runbooks for execution

5. **✓ Data Collection** (optional)
   - Starts VM data collection
   - Starts pricing data collection
   - Can wait for completion

6. **✓ API Configuration**
   - Updates Data API Builder config
   - Backs up old configuration

7. **✓ Container Deployment** (optional)
   - Builds new Docker image
   - Pushes to Azure Container Registry
   - Updates App Service
   - Restarts application

8. **✓ Schedule Setup** (optional)
   - Daily VM data collection (2 AM UTC)
   - Weekly pricing collection (Sunday 3 AM UTC)

9. **✓ Testing**
   - Tests REST API endpoints
   - Tests GraphQL endpoint
   - Verifies deployment

10. **✓ Summary Report**
    - Lists completed steps
    - Provides next steps
    - Shows rollback information

## Prerequisites

### Required Tools

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# SQL Command Line Tools
# macOS
brew install azure-cli sqlcmd

# Linux
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/prod.list)"
sudo apt-get update
sudo apt-get install mssql-tools unixodbc-dev

# sqlpackage
# Download from: https://aka.ms/sqlpackage

# Docker (optional, for container deployment)
# Install from: https://docs.docker.com/get-docker/
```

### Azure Authentication

```bash
# Login to Azure
az login

# Verify subscription
az account show

# Set correct subscription if needed
az account set --subscription "Your Subscription Name"
```

### Azure Permissions Required

- **SQL Database**: Contributor or higher
- **Automation Account**: Contributor or higher
- **App Service**: Contributor or higher
- **Container Registry**: Contributor or higher
- **Resource Group**: Contributor or higher

## Usage

### Basic Deployment

```bash
./deploy-pricing-upgrade.sh
```

The script will prompt you at each major step:
- Confirm configuration
- Run data collection (can take 30-60 minutes)
- Wait for VM collection to complete
- Deploy container (requires Docker)
- Setup schedules

### Unattended Deployment

For CI/CD or automated deployments, you can skip interactive prompts:

```bash
# Set environment variable to skip prompts
export DEPLOY_NONINTERACTIVE=true

# Or use 'yes' to auto-confirm
yes | ./deploy-pricing-upgrade.sh
```

### Dry Run

To see what would happen without making changes:

```bash
# Check prerequisites only
./deploy-pricing-upgrade.sh --check

# (Note: Full dry-run mode not yet implemented)
```

## Configuration

Edit these variables at the top of the script if your setup differs:

```bash
RESOURCE_GROUP="DataAPIBuilder"
SQL_SERVER="dataapibuilderdemo"
DATABASE="VMSizes"
AUTOMATION_ACCOUNT="VMSizes"
WEBAPP_NAME="vmsizesazure"
ACR_NAME="dataapibuilderdemojd"
LOCATION="eastus"
```

## Output Files

### Logs

```
deployment-YYYYMMDD-HHMMSS.log  - Complete deployment log
```

### Backups

```
backups/
├── VMSizes-backup-YYYYMMDD-HHMMSS.dacpac  - Database backup
├── dab-config-backup-YYYYMMDD-HHMMSS.json - Config backup
├── latest-backup.txt                       - Path to latest backup
└── schema-upgrade-output.log               - SQL execution output
```

## Error Handling

### Automatic Rollback

If an error occurs, the script will:
1. Display clear error message
2. Show rollback instructions
3. Save state to logs
4. Exit with error code

### Manual Rollback

```bash
# Restore database from backup
BACKUP_FILE=$(cat backups/latest-backup.txt)
sqlpackage /Action:Publish \
  /SourceFile:"${BACKUP_FILE}" \
  /TargetServerName:dataapibuilderdemo.database.windows.net \
  /TargetDatabaseName:VMSizes
```

## Troubleshooting

### Script fails at prerequisites check

**Solution**: Install missing tools and ensure Azure login

```bash
az login
az account show
```

### Database backup fails

**Solution**: Install sqlpackage or skip backup

The script will continue even if backup fails, as the schema uses MERGE/UPSERT operations that are non-destructive.

### SQL script fails

**Solution**: Check SQL output log

```bash
cat backups/schema-upgrade-output.log
```

Common issues:
- Insufficient permissions
- Firewall blocking connection
- Database not found

### Runbook upload fails

**Solution**: Verify Automation Account exists and permissions

```bash
az automation account show \
  --resource-group DataAPIBuilder \
  --name VMSizes
```

### Container build fails

**Solution**: Check Docker daemon and ACR permissions

```bash
docker ps
az acr login --name dataapibuilderdemojd
```

### API tests fail

**Solution**: Wait a few minutes for App Service to fully start

```bash
# Check app service status
az webapp show \
  --resource-group DataAPIBuilder \
  --name vmsizesazure \
  --query state

# View logs
az webapp log tail \
  --resource-group DataAPIBuilder \
  --name vmsizesazure
```

## Advanced Usage

### Deploy Only Specific Steps

Modify the script's main() function to comment out steps you don't want:

```bash
main() {
    print_banner
    check_prerequisites
    confirm_deployment

    # backup_database      # Skip backup
    upgrade_schema
    upload_runbooks
    # run_data_collection  # Skip data collection
    update_api_config
    # deploy_container     # Skip container
    # setup_schedules      # Skip schedules
    test_deployment

    print_summary
}
```

### Custom Configuration

Set environment variables before running:

```bash
export RESOURCE_GROUP="MyResourceGroup"
export SQL_SERVER="myserver"
export DATABASE="MyDatabase"

./deploy-pricing-upgrade.sh
```

### Run in Different Azure Region

```bash
export LOCATION="westus2"
./deploy-pricing-upgrade.sh
```

## Script Output Example

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   VMSizes Database - Pricing Feature Upgrade                 ║
║   Version 2.0                                                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

2026-02-16 19:45:00 [INFO] Checking prerequisites...
2026-02-16 19:45:01 [SUCCESS] ✓ Azure CLI found: 2.67.0
2026-02-16 19:45:02 [SUCCESS] ✓ sqlpackage found: 162.5.57.1
2026-02-16 19:45:03 [SUCCESS] ✓ sqlcmd found
2026-02-16 19:45:04 [SUCCESS] ✓ Docker found: Docker version 24.0.7
2026-02-16 19:45:05 [SUCCESS] ✓ Logged into Azure: Contoso Ltd
2026-02-16 19:45:06 [SUCCESS] ✓ All prerequisites met

Deployment Configuration:
  Resource Group:      DataAPIBuilder
  SQL Server:          dataapibuilderdemo.database.windows.net
  Database:            VMSizes
  Automation Account:  VMSizes
  Web App:             vmsizesazure
  Container Registry:  dataapibuilderdemojd
  Location:            eastus

Do you want to proceed with the upgrade? [y/N]: y

2026-02-16 19:45:15 [INFO] Starting deployment...

2026-02-16 19:45:16 [INFO] Step 1: Backing up database...
2026-02-16 19:45:17 [INFO] Getting Azure SQL access token...
2026-02-16 19:45:18 [INFO] Extracting database to: ./backups/VMSizes-backup-20260216-194518.dacpac
2026-02-16 19:47:23 [SUCCESS] ✓ Database backed up successfully

[... continues with all steps ...]

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ✓ Deployment Complete!                                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

2026-02-16 20:15:32 [INFO] Deployment Summary:
  ✓ Database schema upgraded
  ✓ Runbooks uploaded (GetData-v2, GetPricingData)
  ✓ Data collection initiated
  ✓ API configuration updated
  ✓ Container deployed
  ✓ Schedules configured

2026-02-16 20:15:33 [SUCCESS] ✓ Upgrade completed successfully!
```

## Post-Deployment

After successful deployment:

1. **Monitor Data Collection**
   ```bash
   # View automation jobs
   az automation job list \
     --automation-account-name VMSizes \
     --resource-group DataAPIBuilder
   ```

2. **Test API Endpoints**
   ```bash
   # Test REST API
   curl https://vmsizesazure.azurewebsites.net/api/vmsizes-pricing | jq '.[0]'

   # Test GraphQL
   curl -X POST https://vmsizesazure.azurewebsites.net/graphql \
     -H "Content-Type: application/json" \
     -d '{"query":"{ regions { items { regionName } } }"}'
   ```

3. **Review Documentation**
   - [SCHEMA-UPGRADE-GUIDE.md](SCHEMA-UPGRADE-GUIDE.md)
   - [API-EXAMPLES-WITH-PRICING.md](API-EXAMPLES-WITH-PRICING.md)
   - [PRICING-FEATURE-SUMMARY.md](PRICING-FEATURE-SUMMARY.md)

## Security Considerations

- ✅ Script uses Azure Managed Identity where possible
- ✅ Access tokens are not logged
- ✅ Backups are stored locally (secure them properly)
- ✅ All operations use HTTPS
- ⚠️ Review Azure RBAC permissions before running
- ⚠️ Logs may contain sensitive connection information

## Contributing

To improve the script:
1. Test changes in dev environment first
2. Add error handling for new steps
3. Update this documentation
4. Submit pull request

## Support

For issues with the script:
1. Check deployment log: `deployment-YYYYMMDD-HHMMSS.log`
2. Review Azure Portal for resource status
3. Check [SCHEMA-UPGRADE-GUIDE.md](SCHEMA-UPGRADE-GUIDE.md) troubleshooting section

## License

This script is part of the DataAPIBuilder-Demo project.
