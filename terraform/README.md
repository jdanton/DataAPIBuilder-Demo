# DataAPIBuilder Terraform Infrastructure

This directory contains Terraform configuration for deploying the complete DataAPIBuilder infrastructure on Azure.

## Overview

This Terraform configuration deploys 20+ Azure resources organized into modular components:

- **Automation**: Azure Automation Account with 6 PowerShell runbooks and schedules
- **SQL**: Azure SQL Server and Database with schema deployment
- **Storage**: Azure Storage Account with containers and file shares
- **Container Registry**: Azure Container Registry for Docker images
- **App Service**: Linux App Service hosting Data API Builder container (with public endpoint)
- **Logic App**: Logic App workflow with managed identity
- **IAM**: Role assignments for managed identities

**Note**: The networking module (Public IP + WAF Policy) is commented out by default. It's available for future Application Gateway deployment if needed.

## Prerequisites

1. **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Terraform** - Version >= 1.6.0 - [Install Terraform](https://www.terraform.io/downloads.html)
3. **Azure Subscription** - With appropriate permissions to create resources
4. **Authentication** - Logged in with `az login`

## Quick Start

### 0. (Optional) Deploy Secure State Storage

For production deployments, it's recommended to use remote state with private endpoint:

```bash
cd bootstrap
./deploy-state-storage.sh
```

This creates:
- **VNet**: vnet-dataapi-eus (10.0.0.0/16) with private endpoint subnet
- **Storage Account**: tfstatedatapibuilder (GRS, private endpoint only)
- **Private DNS Zone**: privatelink.blob.core.windows.net
- **Management Lock**: Prevents accidental deletion

**Important**: The state storage has public access disabled. You'll need VPN/Bastion access to vnet-dataapi-eus.

See [bootstrap/README.md](bootstrap/README.md) for detailed instructions.

After deploying, update `backend.tf` with the output and run `terraform init -reconfigure`.

### 1. Configure Variables

Create a `terraform.tfvars` file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update these required values:

- `subscription_id` - Your Azure subscription ID
- `sql_admin_password` - Strong password for SQL Server
- `sql_aad_admin_object_id` - Your Azure AD user object ID
- `allowed_client_ips` - Your client IP addresses (optional)

Get your Azure AD user object ID:
```bash
az ad signed-in-user show --query id -o tsv
```

Get your subscription ID:
```bash
az account show --query id -o tsv
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Review the Plan

```bash
terraform plan -out=tfplan
```

### 4. Deploy Infrastructure

```bash
terraform apply tfplan
```

The deployment will take approximately 15-20 minutes.

### 5. Verify Deployment

After successful deployment, Terraform will output the API endpoints:

```bash
terraform output
```

Test the Data API Builder endpoints:

```bash
# REST API
curl https://<web-app-name>.azurewebsites.net/api/vmsizes

# GraphQL endpoint
curl https://<web-app-name>.azurewebsites.net/graphql
```

## Environment-Specific Deployments

Use environment-specific variable files for dev, staging, or production:

### Development
```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### Staging
```bash
terraform apply -var-file="environments/staging/terraform.tfvars"
```

### Production
```bash
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## Remote State Management (Recommended)

For team collaboration, configure remote state storage:

### 1. Create State Storage Account

```bash
az group create --name terraform-state-rg --location eastus
az storage account create \
  --name tfstatedatapibuilder \
  --resource-group terraform-state-rg \
  --sku Standard_LRS
az storage container create \
  --name tfstate \
  --account-name tfstatedatapibuilder
```

### 2. Enable Backend

Uncomment the `backend "azurerm"` block in `backend.tf` and run:

```bash
terraform init -reconfigure
```

## Module Structure

```
terraform/
├── main.tf                    # Root module orchestration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Provider configuration
├── backend.tf                 # Remote state config
├── terraform.tfvars.example   # Example variables
├── modules/
│   ├── automation/            # Automation Account + runbooks
│   ├── sql/                   # SQL Server + Database
│   ├── storage/               # Storage Account + containers
│   ├── container-registry/    # Azure Container Registry
│   ├── app-service/           # App Service Plan + Web App (public endpoint)
│   ├── logic-app/             # Logic App workflow
│   ├── networking/            # Public IP + WAF (optional - for App Gateway)
│   └── iam/                   # Role assignments
├── files/
│   ├── runbooks/              # PowerShell runbooks
│   ├── sql/                   # Database schema SQL
│   └── config/                # DAB configuration
└── environments/
    ├── dev/
    ├── staging/
    └── prod/
```

## Architecture

The deployed infrastructure creates a serverless data API platform:

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
              ┌────────────────────┐
              │  App Service       │
              │  (vmsizesazure)    │  ← Public HTTPS endpoint
              │                    │     https://vmsizesazure.azurewebsites.net
              └────────┬───────────┘
                       │
                       ▼
              ┌────────────────────┐
              │ Data API Builder   │  ← REST API: /api/*
              │ (Container)        │  ← GraphQL: /graphql
              └────────┬───────────┘
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
┌────────────────┐         ┌─────────────────┐
│  Azure Files   │         │   SQL Database  │
│  (Config)      │         │   (VMSizes)     │
└────────────────┘         └─────────────────┘

Background Data Collection:
┌──────────────────────┐
│ Automation Account   │  ← Scheduled runbooks
│ - GetData-v2 (Daily) │  ← Collect VM sizes
│ - GetPricing (Weekly)│  ← Update pricing
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Blob Storage        │  ← JSON/Parquet data
│  (5 containers)      │
└──────────────────────┘
```

**Note**: App Service provides its own public endpoint. There is no Application Gateway or separate Public IP in the base deployment. The networking module (Public IP + WAF Policy) is available but commented out for future Application Gateway deployment.

## Key Resources Created

| Resource | Type | Purpose |
|----------|------|---------|
| VMSizes | Automation Account | Hosts runbooks for data collection |
| GetData-v2 | Runbook | Collects VM size data daily |
| GetPricingData | Runbook | Updates pricing data weekly |
| dataapibuilderdemo | SQL Server | Hosts VMSizes database |
| VMSizes | SQL Database | Stores VM and pricing data |
| datapibuilderdemo | Storage Account | Blob storage and file shares |
| filestore | File Share | Stores DAB configuration |
| dataapibuilderdemojd | Container Registry | Hosts DAB container images |
| vmsizesazure | Web App | Runs Data API Builder container |
| VMSizesLogicApp | Logic App | Workflow automation (placeholder) |

## Database Schema

The SQL module automatically deploys this schema:

**Tables:**
- VMSizes - Virtual machine configurations
- AzureRegions - Azure regions
- VMFamilies - VM family classifications
- PricingModels - Pricing model types
- Currencies - Supported currencies
- VMPricing - VM pricing data
- VMSizeRegionalAvailability - Regional availability
- DataLoadHistory - Data load tracking

**Views:**
- vw_VMSizesWithPricing - VM sizes with current pricing
- vw_PriceComparisonByRegion - Regional price comparisons

**Stored Procedures:**
- usp_UpsertVMSize - Insert/update VM sizes
- usp_UpsertVMPricing - Insert/update pricing data

## Automation Schedules

| Schedule | Frequency | Runbook | Purpose |
|----------|-----------|---------|---------|
| Daily VM Collection | Daily | GetData-v2 | Collect VM sizes and metadata |
| Weekly Pricing Update | Weekly (Sunday) | GetPricingData | Update pricing data |
| Nightly Cost Management | Daily | Azure-Cost-Management | Cost reporting |

## Secrets Management

**Important**: Never commit sensitive values to version control.

### Option 1: Environment Variables
```bash
export TF_VAR_sql_admin_password="YourStrongPassword"
export TF_VAR_subscription_id="your-subscription-id"
terraform apply
```

### Option 2: Azure Key Vault (Recommended)
Store secrets in Azure Key Vault and reference them:

```hcl
data "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-admin-password"
  key_vault_id = var.key_vault_id
}
```

## Troubleshooting

### Schema Deployment Fails

If the database schema deployment fails, you can skip it and deploy manually:

1. Set `deploy_schema = false` in the SQL module call
2. Apply the configuration
3. Manually execute the SQL script in Azure Portal Query Editor

### Authentication Issues

Ensure you're logged in to Azure CLI:
```bash
az login
az account set --subscription <subscription-id>
```

### Resource Name Conflicts

If resources already exist with the same names, either:
1. Change the resource names in `terraform.tfvars`
2. Import existing resources: `terraform import <resource> <id>`

### Module Dependency Errors

Ensure all required modules are initialized:
```bash
terraform init -upgrade
```

## Importing Existing Resources

To import existing Azure resources into Terraform state:

```bash
# Example: Import SQL Server
terraform import module.sql.azurerm_mssql_server.main \
  /subscriptions/{sub-id}/resourceGroups/DataAPIBuilder/providers/Microsoft.Sql/servers/dataapibuilderdemo

# Example: Import Storage Account
terraform import module.storage.azurerm_storage_account.main \
  /subscriptions/{sub-id}/resourceGroups/DataAPIBuilder/providers/Microsoft.Storage/storageAccounts/datapibuilderdemo
```

## Outputs

After deployment, these outputs are available:

```bash
terraform output app_service_url          # Web app URL
terraform output rest_api_endpoint        # REST API endpoint
terraform output graphql_endpoint         # GraphQL endpoint
terraform output sql_server_fqdn          # SQL Server FQDN (sensitive)
terraform output automation_account_id    # Automation account ID
```

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources and data. Ensure you have backups.

## Cost Considerations

Estimated monthly costs (US East):
- **Development**: ~$50-100/month (Basic SKUs)
- **Staging**: ~$150-250/month (Standard SKUs)
- **Production**: ~$200-400/month (depends on usage)

Major cost drivers:
- SQL Database (Standard S0: ~$15/month)
- App Service Plan (B1: ~$13/month)
- Storage Account (~$5-20/month)
- Container Registry (Standard: ~$20/month)

## Additional Documentation

- [Main Architecture Documentation](../ARCHITECTURE.md)
- [API Examples](../API-EXAMPLES-WITH-PRICING.md)
- [Schema Upgrade Guide](../SCHEMA-UPGRADE-GUIDE.md)
- [Deployment Script](../deploy-pricing-upgrade.sh)

## Support

For issues or questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Review Terraform plan output for errors
3. Check Azure Portal for resource status
4. Review module-specific documentation

## License

This Terraform configuration is part of the DataAPIBuilder project.
