# DataAPIBuilder-Demo

This repository contains the complete Azure infrastructure and automation code for demonstrating Azure Data API Builder capabilities. The system collects Azure VM SKU information across all regions and exposes it through a REST/GraphQL API.

## What This Demo Shows

- Automated data collection using Azure Automation with Managed Identity
- Data storage in Azure SQL Database
- REST/GraphQL API generation using Data API Builder
- Container-based hosting on Azure App Service
- Complete Infrastructure as Code (Bicep templates)

## Quick Start

### Prerequisites
- Azure CLI installed and authenticated
- Azure subscription with appropriate permissions
- Bicep CLI (included with Azure CLI)

### Deploy Infrastructure

```bash
# Clone the repository
git clone <your-repo-url>
cd DataAPIBuilder-Demo

# Deploy using Bicep
az deployment group create \
  --resource-group DataAPIBuilder \
  --template-file bicep/main.bicep

# Or deploy using ARM template
az deployment group create \
  --resource-group DataAPIBuilder \
  --template-file azure-resources-export.json
```

### Manual Setup (Alternative)

1. Create the resource group
2. Deploy resources using the Azure Portal or CLI
3. Configure Managed Identity for the Automation Account
4. Import runbooks from the [runbooks/](runbooks/) directory
5. Configure App Service to pull from Container Registry
6. Set up Data API Builder configuration

## Repository Contents

- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Detailed architecture documentation and data flow
- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Step-by-step Azure deployment guide
- **[RESOURCE-INVENTORY.md](RESOURCE-INVENTORY.md)**: Complete resource inventory with costs
- **[CONTAINER-BUILD.md](CONTAINER-BUILD.md)**: Docker container build and deployment guide
- **[runbooks/](runbooks/)**: PowerShell automation scripts
  - GetData.ps1: Main data collection runbook
  - Cleanup.ps1: Data cleanup automation
  - Azure-Cost-Management.ps1: Cost reporting
- **[bicep/](bicep/)**: Infrastructure as Code templates
- **[logic-apps/](logic-apps/)**: Logic App workflow definitions
- **[app-service/](app-service/)**: Web App configuration
- **[sql/](sql/)**: SQL Database configuration and schemas
  - **VMSizes.dacpac**: Complete database export from Azure SQL (43KB)
  - **DATABASE-SCHEMA-SUMMARY.md**: Full schema documentation
  - init-db.sql: Database schema and initialization
  - sample-queries.sql: Example SQL queries (15+ examples)
  - model.xml: Database model extracted from DACPAC
- **Container Files**:
  - Dockerfile: Build Data API Builder from SDK
  - Dockerfile.alternative: Use official Microsoft image (recommended)
  - docker-compose.yml: Local development environment
  - dab-config.template.json: Data API Builder configuration template
  - .dockerignore: Docker build exclusions

## Architecture Overview

```
Azure Automation → Azure API → Blob Storage → SQL Database → Data API Builder → API Gateway
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.

## Resources Deployed

- Azure Automation Account with 6 runbooks
- Azure SQL Database (VMSizes)
- Storage Account with blob containers
- Container Registry (Data API Builder image)
- App Service (Linux container)
- Logic App with API connections
- Application Gateway with WAF policy

## Running the Demo

1. Trigger the GetData runbook (manually or via schedule)
2. Monitor job execution in Azure Automation
3. Check blob storage for collected JSON data
4. Query the Data API Builder endpoint
5. Show GraphQL/REST API capabilities

## API Endpoints

The Data API Builder provides:
- REST API: `https://vmsizesazure.azurewebsites.net/api/...`
- GraphQL: `https://vmsizesazure.azurewebsites.net/graphql`

(Exact endpoints depend on Data API Builder configuration)

## Security

- Uses Azure Managed Identity for authentication
- Container images stored in private ACR
- SQL Database with firewall rules
- Application Gateway with WAF protection

## Cost Optimization

The Azure-Cost-Management runbook provides cost tracking and reporting. Review regularly to optimize resource usage.

## Contributing

This is a demo repository. Feel free to use it as a reference for your own Data API Builder implementations.

## Resources

- [Data API Builder Documentation](https://learn.microsoft.com/azure/data-api-builder/)
- [Azure Automation Documentation](https://learn.microsoft.com/azure/automation/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
