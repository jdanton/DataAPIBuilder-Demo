# Azure Resource Inventory

## Resource Group
- **Name**: DataAPIBuilder
- **Location**: East US
- **Subscription**: Contoso Ltd (424d0f78-5980-4d31-98ec-624616db8e74)

## All Resources (22 total)

### Compute & Automation

| Resource Name | Type | Purpose |
|--------------|------|---------|
| VMSizes | Automation Account | Orchestrates data collection and automation tasks |
| VMSizes/GetData | Runbook | Collects VM SKU data from Azure APIs |
| VMSizes/Cleanup | Runbook | Cleans up old data |
| VMSizes/Azure-Cost-Management | Runbook | Tracks and reports Azure costs |
| VMSizes/AzureAutomationTutorialWithIdentity | Runbook | Tutorial example |
| VMSizes/AzureAutomationTutorialWithIdentityGraphical | Runbook (Graphical) | Graphical tutorial |
| VMSizes/PythonDemo | Runbook (Python) | Python automation example |

### Storage

| Resource Name | Type | Purpose |
|--------------|------|---------|
| datapibuilderdemo | Storage Account | Stores collected VM data as JSON blobs |

**Containers**:
- `json`: VM SKU data per region (my{region}.json)
- `status`: Job completion markers (completed{timestamp}.txt)

### Database

| Resource Name | Type | Purpose |
|--------------|------|---------|
| dataapibuilderdemo | SQL Server | Hosts SQL databases |
| dataapibuilderdemo/VMSizes | SQL Database | Stores VM size data for API queries |
| dataapibuilderdemo/master | SQL Database | System database |

**Connection String Template**:
```
Server=tcp:dataapibuilderdemo.database.windows.net,1433;Database=VMSizes;Authentication=Active Directory Default;
```

### Containers

| Resource Name | Type | Purpose |
|--------------|------|---------|
| dataapibuilderdemojd | Container Registry | Stores Data API Builder container images |

**Images**:
- `azure-databases/data-api-builder`

**Registry URL**: `dataapibuilderdemojd.azurecr.io`

### Web Apps

| Resource Name | Type | Purpose |
|--------------|------|---------|
| ASP-DataAPIBuilder-a8e9 | App Service Plan | Hosts the web application (Linux, B1 tier) |
| vmsizesazure | App Service (Web App) | Runs Data API Builder container |

**App URL**: `https://vmsizesazure.azurewebsites.net`

**Container Configuration**:
- Registry: dataapibuilderdemojd.azurecr.io
- Image: azure-databases/data-api-builder

### Integration

| Resource Name | Type | Purpose |
|--------------|------|---------|
| VMSizesLogicApp | Logic App | Workflow orchestration |
| azureblob | API Connection | Connects Logic App to Blob Storage |
| sql | API Connection | Connects Logic App to SQL Database |
| sql-1 | API Connection | Additional SQL connection |
| sql-2 | API Connection | Additional SQL connection |
| azureautomation | API Connection | Connects Logic App to Automation |

### Networking

| Resource Name | Type | Purpose |
|--------------|------|---------|
| appgw-pip-datapibuilder | Public IP Address | Public IP for Application Gateway |
| DemoAppGW-WAF-Policy | WAF Policy | Web Application Firewall rules |

## Resource Dependencies

```
┌─────────────────────┐
│ VMSizes             │
│ (Automation)        │◄──┐
└──────┬──────────────┘   │
       │                  │
       │ Managed          │ Triggers
       │ Identity         │
       │                  │
       ▼                  │
┌─────────────────────┐   │
│ datapibuilderdemo   │   │
│ (Storage)           │   │
└──────┬──────────────┘   │
       │                  │
       │ Data Flow        │
       │                  │
       ▼                  │
┌─────────────────────┐   │
│ dataapibuilderdemo  │   │
│ (SQL Database)      │   │
└──────┬──────────────┘   │
       │                  │
       │ Data Source      │
       │                  │
       ▼                  │
┌─────────────────────┐   │
│ vmsizesazure        │   │
│ (App Service)       │   │
│                     │   │
│ ┌─────────────────┐ │   │
│ │ Data API Builder│ │   │
│ │ Container       │ │   │
│ └─────────────────┘ │   │
└──────┬──────────────┘   │
       │                  │
       ▼                  │
┌─────────────────────┐   │
│ Application Gateway │   │
│ + WAF               │   │
└─────────────────────┘   │
                          │
┌─────────────────────┐   │
│ VMSizesLogicApp     │───┘
│ (Orchestration)     │
└─────────────────────┘
```

## Resource Tags

(No custom tags currently applied - consider adding tags for cost tracking)

## Managed Identities

| Identity | Type | Used By | Permissions |
|----------|------|---------|-------------|
| VMSizes | System-Assigned | Automation Account | Reader (subscription), Storage Blob Data Contributor |

## Access & Security

### Firewall Rules
- SQL Server: Allows Azure services (0.0.0.0)
- Storage Account: Public access with managed identity

### Authentication Methods
- Automation Runbooks: Managed Identity
- App Service → SQL: Connection string or Managed Identity
- App Service → ACR: Registry credentials or Managed Identity

## Cost Breakdown (Estimated Monthly)

| Resource Type | Tier/SKU | Est. Cost |
|---------------|----------|-----------|
| Automation Account | Basic | $0.50 + usage |
| SQL Database | Basic | $5.00 |
| Storage Account | Standard LRS | $0.50 |
| Container Registry | Basic | $5.00 |
| App Service Plan | B1 (Linux) | $13.00 |
| Logic App | Consumption | Pay-per-execution |
| Public IP | Static | $3.00 |
| WAF Policy | - | Included with App Gateway |

**Estimated Total: $27-55/month** (depending on App Gateway deployment)

## Monitoring Recommendations

1. Enable Application Insights for App Service
2. Set up Log Analytics workspace
3. Configure alerts for:
   - Automation job failures
   - SQL Database DTU > 80%
   - App Service CPU > 80%
   - Storage account throttling
4. Track costs with Azure Cost Management

## Backup Strategy

- **SQL Database**: Configure automated backups (7-day retention on Basic tier)
- **Automation Runbooks**: Stored in this Git repository
- **Container Images**: Maintain in ACR with versioning
- **Storage Account**: Enable soft delete for blob containers

## Compliance & Governance

- Consider implementing:
  - Azure Policy for resource compliance
  - Resource locks for production resources
  - Azure Blueprints for standardized deployments
  - Key Vault for secrets management

## Exported Configuration Files

All resource configurations have been exported to this repository:

- [azure-resources-export.json](azure-resources-export.json) - Complete ARM template
- [resources-list.json](resources-list.json) - Resource inventory JSON
- [bicep/main.bicep](bicep/main.bicep) - Bicep IaC template
- [runbooks/](runbooks/) - All automation scripts
- [sql/database-config.json](sql/database-config.json) - Database configuration
- [app-service/](app-service/) - Web app configuration
- [logic-apps/](logic-apps/) - Logic App definitions
- [storage-account-config.json](storage-account-config.json) - Storage settings
- [container-registry-config.json](container-registry-config.json) - ACR settings

## Last Updated
2026-02-16

## Next Actions
- [ ] Document Data API Builder configuration file (dab-config.json)
- [ ] Add example API queries and responses
- [ ] Configure monitoring and alerts
- [ ] Set up automated backups
- [ ] Implement CI/CD pipeline
- [ ] Add resource tags for cost tracking
