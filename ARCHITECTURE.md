# DataAPIBuilder Architecture Documentation

## Overview
This repository contains the complete Azure infrastructure and code for the Data API Builder Demo presentation. The system collects Azure VM SKU data across all regions and makes it available through a Data API Builder endpoint.

## Architecture Components

### 1. Azure Automation (VMSizes)
**Purpose**: Orchestrate data collection and management tasks

#### Runbooks
- **GetData.ps1**: Main data collection runbook that:
  - Connects to Azure using Managed Identity
  - Iterates through all physical Azure regions
  - Collects VM SKU capabilities (CPU, Memory, IOPS, NICs, etc.)
  - Stores JSON output to blob storage (one file per region)
  - Creates completion markers in status container

- **Cleanup.ps1**: Maintenance runbook for cleaning up old data

- **Azure-Cost-Management.ps1**: Cost reporting and management automation

- **AzureAutomationTutorialWithIdentity.ps1**: Tutorial/example runbook demonstrating Managed Identity usage

- **PythonDemo**: Python-based runbook (New state)

- **AzureAutomationTutorialWithIdentityGraphical**: Graphical PowerShell runbook (Published)

**Authentication**: Uses System-Assigned Managed Identity

### 2. Azure SQL Database
- **Server**: `dataapibuilderdemo.database.windows.net`
- **Database**: `VMSizes`
- **Purpose**: Stores VM size data for querying via Data API Builder
- **Configuration**: See [sql/database-config.json](sql/database-config.json)

### 3. Storage Account (datapibuilderdemo)
**Purpose**: Intermediate storage for collected data
- **Containers**:
  - `json`: Stores VM SKU data per region (my{region}.json files)
  - `status`: Stores completion markers with timestamps
- **Access**: Uses Managed Identity for authentication
- **Configuration**: See [storage-account-config.json](storage-account-config.json)

### 4. Logic App (VMSizesLogicApp)
**Purpose**: Workflow orchestration (currently empty definition)
- Can be used to trigger automation runbooks
- Orchestrate data flow between services
- **API Connections Available**:
  - `azureblob`: Blob storage connector
  - `sql`, `sql-1`, `sql-2`: SQL database connectors
  - `azureautomation`: Automation account connector
- **Configuration**: See [logic-apps/VMSizesLogicApp.json](logic-apps/VMSizesLogicApp.json)

### 5. Azure Container Registry (dataapibuilderdemojd)
**Registry URL**: `dataapibuilderdemojd.azurecr.io`
**Images**:
- `azure-databases/data-api-builder`: The Data API Builder container image
**Configuration**: See [container-registry-config.json](container-registry-config.json)

### 6. App Service (vmsizesazure)
**Purpose**: Hosts the Data API Builder application
- **Hosting Model**: Linux Container
- **Container Source**: Azure Container Registry (dataapibuilderdemojd)
- **App Service Plan**: ASP-DataAPIBuilder-a8e9 (East US)
- **Configuration Files**:
  - [app-service/webapp-config.json](app-service/webapp-config.json)
  - [app-service/app-settings.json](app-service/app-settings.json)
  - [app-service/deployment-source.json](app-service/deployment-source.json)

**Key Settings**:
```json
{
  "DOCKER_REGISTRY_SERVER_URL": "https://dataapibuilderdemojd.azurecr.io",
  "DOCKER_REGISTRY_SERVER_USERNAME": "dataapibuilderdemojd"
}
```

### 7. Application Gateway (Planned)
- **Public IP**: `appgw-pip-datapibuilder`
- **WAF Policy**: `DemoAppGW-WAF-Policy`
- **Purpose**: Provides WAF protection and load balancing for the API endpoint

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Azure Automation Runbook (GetData)                       │
│    - Triggered on schedule or manually                      │
│    - Uses Managed Identity for authentication               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Azure Compute API                                        │
│    - Get-AzLocation (list regions)                          │
│    - Get-AzComputeResourceSku (VM capabilities)             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Blob Storage (datapibuilderdemo)                         │
│    - Container: json/my{region}.json                        │
│    - Container: status/completed{timestamp}.txt             │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. SQL Database (VMSizes)                                   │
│    - Data imported/synchronized from blob storage           │
│    - Serves as backend for Data API Builder                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Data API Builder (Container App)                         │
│    - Hosted on App Service (vmsizesazure)                   │
│    - Provides REST/GraphQL API over SQL data                │
│    - Container from ACR: azure-databases/data-api-builder   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Application Gateway (with WAF)                           │
│    - Public endpoint for API consumers                      │
│    - Security and traffic management                        │
└─────────────────────────────────────────────────────────────┘
```

## Infrastructure as Code

### Bicep Template
The complete infrastructure is defined in Bicep format: [bicep/main.bicep](bicep/main.bicep)

To deploy:
```bash
az deployment group create \
  --resource-group DataAPIBuilder \
  --template-file bicep/main.bicep
```

### ARM Template
Raw ARM export available: [azure-resources-export.json](azure-resources-export.json)

## Security & Identity

### Managed Identity Usage
The Automation Account uses System-Assigned Managed Identity with the following permissions:
- Read access to Azure Compute API (to query VM SKUs)
- Write access to Storage Account (to store JSON data)
- Contributor access to SQL Database (to update data)

### Container Registry Authentication
The App Service uses managed identity or registry credentials to pull container images.

## Monitoring & Operations

### Automation Runbook Execution
- Runbooks can be triggered manually or on schedule
- Job history and logs available in Azure Automation
- Completion markers written to `status` container

### Data Freshness
- Check the `status` container for latest completion timestamp
- Each region's data stored as separate JSON file in `json` container

## Resource Locations
All resources are deployed in **East US** region.

## Resource Naming Convention
- Resource Group: `DataAPIBuilder`
- Automation Account: `VMSizes`
- Storage Account: `datapibuilderdemo`
- SQL Server: `dataapibuilderdemo`
- SQL Database: `VMSizes`
- Container Registry: `dataapibuilderdemojd`
- App Service: `vmsizesazure`
- Logic App: `VMSizesLogicApp`

## Repository Structure
```
DataAPIBuilder-Demo/
├── README.md                           # Project overview
├── ARCHITECTURE.md                     # This file
├── automation.ps1                      # Original automation script
├── runbooks/                           # All automation runbooks
│   ├── GetData.ps1                    # Main data collection
│   ├── Cleanup.ps1                    # Cleanup automation
│   ├── Azure-Cost-Management.ps1      # Cost management
│   └── AzureAutomationTutorialWithIdentity.ps1
├── logic-apps/                         # Logic App definitions
│   └── VMSizesLogicApp.json
├── sql/                                # SQL database configs
│   └── database-config.json
├── app-service/                        # App Service configs
│   ├── webapp-config.json
│   ├── app-settings.json
│   └── deployment-source.json
├── bicep/                              # Infrastructure as Code
│   └── main.bicep                     # Complete Bicep template
├── azure-resources-export.json         # ARM template export
├── resources-list.json                 # Resource inventory
├── storage-account-config.json         # Storage account details
├── container-registry-config.json      # ACR configuration
└── acr-repositories.json              # Container images list
```

## Data API Builder

The Data API Builder container provides automatic REST and GraphQL endpoints for the SQL database. It:
- Exposes VM size data via RESTful API
- Supports OData query syntax
- Provides GraphQL endpoint for flexible queries
- Handles authentication and authorization
- Optimizes SQL query generation

### Example Queries
(Configuration file needed to show exact endpoints)

## Next Steps

To fully document the Data API Builder configuration:
1. Pull the container configuration from the App Service
2. Document the dab-config.json schema mapping
3. List available API endpoints
4. Add example API calls and responses

## Presentation Demo Flow

1. Show automated data collection via Azure Automation
2. Demonstrate data stored in Blob Storage (JSON per region)
3. Show SQL database populated with VM SKU data
4. Access Data API Builder endpoints to query VM sizes
5. Demonstrate filtering, sorting, and pagination via API
