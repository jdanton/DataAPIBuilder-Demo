# Deployment Guide

## Prerequisites

1. **Azure Subscription** with the following permissions:
   - Resource Group Contributor
   - Role Assignment Administrator (for Managed Identity)

2. **Tools Required**:
   - Azure CLI 2.50.0 or later
   - Bicep CLI (included with Azure CLI)
   - PowerShell 7+ (for testing runbooks locally)
   - Git

## Step-by-Step Deployment

### 1. Create Resource Group

```bash
az group create \
  --name DataAPIBuilder \
  --location eastus
```

### 2. Deploy Infrastructure

#### Option A: Using Bicep (Recommended)

```bash
cd DataAPIBuilder-Demo

# Validate the template
az deployment group validate \
  --resource-group DataAPIBuilder \
  --template-file bicep/main.bicep

# Deploy
az deployment group create \
  --resource-group DataAPIBuilder \
  --template-file bicep/main.bicep \
  --verbose
```

#### Option B: Using ARM Template

```bash
az deployment group create \
  --resource-group DataAPIBuilder \
  --template-file azure-resources-export.json
```

### 3. Configure Managed Identity

The Automation Account needs permissions to:
- Read Azure Compute API data
- Write to Storage Account
- Access SQL Database

```bash
# Get the Automation Account's Managed Identity
PRINCIPAL_ID=$(az automation account show \
  --resource-group DataAPIBuilder \
  --automation-account-name VMSizes \
  --query identity.principalId -o tsv)

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Assign Reader role for Azure Compute API access
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Reader" \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Assign Storage Blob Data Contributor
STORAGE_ID=$(az storage account show \
  --resource-group DataAPIBuilder \
  --name datapibuilderdemo \
  --query id -o tsv)

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope $STORAGE_ID
```

### 4. Import Automation Runbooks

```bash
# GetData runbook
az automation runbook create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData \
  --type PowerShell72 \
  --location eastus

az automation runbook replace-content \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData \
  --content @runbooks/GetData.ps1

az automation runbook publish \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData

# Repeat for other runbooks
for runbook in Cleanup Azure-Cost-Management; do
  az automation runbook create \
    --automation-account-name VMSizes \
    --resource-group DataAPIBuilder \
    --name $runbook \
    --type PowerShell72 \
    --location eastus

  az automation runbook replace-content \
    --automation-account-name VMSizes \
    --resource-group DataAPIBuilder \
    --name $runbook \
    --content @runbooks/${runbook}.ps1

  az automation runbook publish \
    --automation-account-name VMSizes \
    --resource-group DataAPIBuilder \
    --name $runbook
done
```

### 5. Create Storage Containers

```bash
# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group DataAPIBuilder \
  --account-name datapibuilderdemo \
  --query '[0].value' -o tsv)

# Create containers
az storage container create \
  --account-name datapibuilderdemo \
  --name json \
  --auth-mode key

az storage container create \
  --account-name datapibuilderdemo \
  --name status \
  --auth-mode key
```

### 6. Configure SQL Database

```bash
# Set up firewall rule for your IP
MY_IP=$(curl -s https://api.ipify.org)

az sql server firewall-rule create \
  --resource-group DataAPIBuilder \
  --server dataapibuilderdemo \
  --name AllowMyIP \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP

# Allow Azure services
az sql server firewall-rule create \
  --resource-group DataAPIBuilder \
  --server dataapibuilderdemo \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### 7. Build and Push Data API Builder Container

If you need to rebuild the container:

```bash
# Login to ACR
az acr login --name dataapibuilderdemojd

# Build and push (from your Data API Builder config directory)
docker build -t dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:latest .
docker push dataapibuilderdemojd.azurecr.io/azure-databases/data-api-builder:latest
```

### 8. Configure App Service

```bash
# Enable container logging
az webapp log config \
  --resource-group DataAPIBuilder \
  --name vmsizesazure \
  --docker-container-logging filesystem

# Restart the app
az webapp restart \
  --resource-group DataAPIBuilder \
  --name vmsizesazure
```

### 9. Test the Deployment

```bash
# Run the GetData runbook
az automation runbook start \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name GetData

# Check job status
JOB_NAME=$(az automation job list \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --query '[0].name' -o tsv)

az automation job show \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --job-name $JOB_NAME

# View job output
az automation job output \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --job-name $JOB_NAME
```

### 10. Verify Data API Builder

```bash
# Get the App Service URL
APP_URL=$(az webapp show \
  --resource-group DataAPIBuilder \
  --name vmsizesazure \
  --query defaultHostName -o tsv)

# Test the API endpoint
curl https://$APP_URL/api/vmsizes

# Test GraphQL endpoint
curl https://$APP_URL/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ vmsizes { name cpu memoryGB region } }"}'
```

## Schedule Automation

Set up a schedule to run the GetData runbook automatically:

```bash
# Create a schedule (daily at 2 AM UTC)
az automation schedule create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --name DailyVMSizeCollection \
  --frequency Day \
  --interval 1 \
  --start-time "2026-02-17T02:00:00+00:00" \
  --time-zone "UTC"

# Link runbook to schedule
az automation job-schedule create \
  --automation-account-name VMSizes \
  --resource-group DataAPIBuilder \
  --runbook-name GetData \
  --schedule-name DailyVMSizeCollection
```

## Troubleshooting

### Runbook Fails with Authentication Error

Check that the Managed Identity has the correct role assignments:

```bash
az role assignment list --assignee $PRINCIPAL_ID --output table
```

### Container App Not Starting

Check the container logs:

```bash
az webapp log tail \
  --resource-group DataAPIBuilder \
  --name vmsizesazure
```

### SQL Connection Issues

Verify firewall rules:

```bash
az sql server firewall-rule list \
  --resource-group DataAPIBuilder \
  --server dataapibuilderdemo \
  --output table
```

## Clean Up

To remove all resources:

```bash
az group delete \
  --name DataAPIBuilder \
  --yes \
  --no-wait
```

## Estimated Deployment Time

- Infrastructure deployment: 10-15 minutes
- Runbook import and configuration: 5 minutes
- First data collection run: 30-60 minutes (depends on number of regions)
- Total: ~1 hour for complete setup

## Cost Estimates

Monthly costs (East US region):
- Azure Automation: ~$0.50 + $0.002/minute runtime
- SQL Database (Basic): ~$5/month
- Storage Account: ~$0.50/month
- App Service (B1): ~$13/month
- Container Registry (Basic): ~$5/month
- Application Gateway: ~$20-30/month (if deployed)

**Total: ~$45-55/month**

## Next Steps

1. Customize the Data API Builder configuration
2. Set up CI/CD pipelines for automated deployments
3. Configure monitoring and alerts
4. Implement backup strategies
5. Set up Logic Apps for advanced workflows
