# Terraform State Storage Bootstrap

This directory contains the bootstrap configuration for Terraform remote state storage with private endpoint connectivity.

## Overview

This bootstrap infrastructure creates:

- **Resource Group**: `terraform-state-rg`
- **Virtual Network**: `vnet-dataapi-eus` (10.0.0.0/16)
- **Subnet**: `snet-private-endpoints` (10.0.1.0/24)
- **Storage Account**: `tfstatedatapibuilder` (GRS replication)
  - Public network access disabled
  - Infrastructure encryption enabled
  - Blob versioning enabled (30-day retention)
- **Private Endpoint**: Access to storage account via VNet
- **Private DNS Zone**: `privatelink.blob.core.windows.net`
- **Management Lock**: Prevents accidental deletion

## Prerequisites

1. Azure CLI installed and authenticated
2. Terraform >= 1.6.0
3. Appropriate Azure permissions to create resources

## Deployment

### 1. Deploy State Storage Infrastructure

```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

### 2. Configure Main Terraform to Use Remote State

After deployment, Terraform will output the backend configuration. Copy it to the main `backend.tf`:

```bash
terraform output -raw backend_config
```

Update `../backend.tf` with the output configuration and run:

```bash
cd ..
terraform init -reconfigure
```

## Security Features

### Private Endpoint
- Storage account is **not accessible** from public internet
- Access only through private endpoint in VNet
- Private IP: Assigned dynamically in subnet

### Encryption
- Infrastructure encryption enabled (double encryption)
- TLS 1.2 minimum
- Encryption at rest (Azure Storage encryption)

### Data Protection
- Blob versioning enabled
- 30-day soft delete for blobs
- 30-day soft delete for containers
- Geo-redundant storage (GRS)
- Management lock prevents deletion

### Access Control
- Private network access only
- Azure RBAC controls access to storage
- State file encryption in transit and at rest

## Network Architecture

```
vnet-dataapi-eus (10.0.0.0/16)
├── snet-private-endpoints (10.0.1.0/24)
│   └── pe-tfstatedatapibuilder
│       └── Private IP → Storage Account
└── Private DNS Zone
    └── privatelink.blob.core.windows.net
        └── tfstatedatapibuilder.blob.core.windows.net → Private IP
```

## Accessing State Storage

### From Azure Cloud Shell
Azure Cloud Shell can access the private endpoint when connected to the VNet via:
- VNet peering
- VPN Gateway
- Azure Bastion

### From Local Machine
To access from your local machine:

1. **Option 1: VPN Connection**
   - Set up Point-to-Site VPN to vnet-dataapi-eus
   - Connect to VPN before running Terraform

2. **Option 2: Bastion/Jump Box**
   - Deploy VM in vnet-dataapi-eus
   - Run Terraform from the VM

3. **Option 3: Temporarily Enable Public Access** (Not Recommended)
   - Enable public network access for deployment
   - Use firewall rules to restrict IPs
   - Disable public access after deployment

## State File Management

### Viewing State
```bash
# Must be connected to VNet
az storage blob list \
  --account-name tfstatedatapibuilder \
  --container-name tfstate \
  --auth-mode login
```

### Downloading State Backup
```bash
az storage blob download \
  --account-name tfstatedatapibuilder \
  --container-name tfstate \
  --name dataapi/terraform.tfstate \
  --file terraform.tfstate.backup \
  --auth-mode login
```

### Viewing State Versions
```bash
az storage blob list \
  --account-name tfstatedatapibuilder \
  --container-name tfstate \
  --prefix dataapi/terraform.tfstate \
  --include v \
  --auth-mode login
```

## Disaster Recovery

### State File Recovery
With 30-day soft delete and versioning enabled:

```bash
# List deleted blobs
az storage blob list \
  --account-name tfstatedatapibuilder \
  --container-name tfstate \
  --include d \
  --auth-mode login

# Undelete a blob
az storage blob undelete \
  --account-name tfstatedatapibuilder \
  --container-name tfstate \
  --name dataapi/terraform.tfstate \
  --auth-mode login
```

### Restore from Version
```bash
# Copy a specific version
az storage blob copy start \
  --account-name tfstatedatapibuilder \
  --destination-blob dataapi/terraform.tfstate \
  --destination-container tfstate \
  --source-blob dataapi/terraform.tfstate \
  --source-container tfstate \
  --source-version-id <version-id> \
  --auth-mode login
```

## Cleanup

**Warning**: Only delete if you're completely removing the infrastructure.

```bash
# Remove management lock first
az lock delete --name state-storage-lock \
  --resource-group terraform-state-rg \
  --resource-type Microsoft.Storage/storageAccounts \
  --resource tfstatedatapibuilder

# Then destroy
terraform destroy
```

## Customization

Edit `variables.tf` or create `terraform.tfvars`:

```hcl
location              = "eastus2"
storage_account_name  = "mycustomstatename"
vnet_name            = "vnet-custom-eus2"
vnet_address_space   = ["10.1.0.0/16"]
```

## Cost Estimate

Approximate monthly cost (US East):
- Storage Account (GRS): ~$5-10/month
- Private Endpoint: ~$7/month
- Virtual Network: Free
- Private DNS Zone: ~$0.50/month

**Total**: ~$13-18/month

## Troubleshooting

### Cannot Access Storage Account
- Ensure you're connected to the VNet (VPN/Bastion)
- Verify private endpoint is provisioned
- Check DNS resolution: `nslookup tfstatedatapibuilder.blob.core.windows.net`

### Terraform Init Fails
- Verify backend configuration in main `backend.tf`
- Ensure storage account name is correct
- Check Azure CLI authentication: `az account show`

### Private Endpoint Not Working
- Verify private DNS zone is linked to VNet
- Check subnet has no network policies blocking private endpoints
- Ensure private endpoint is in "Succeeded" state

## Additional Resources

- [Azure Storage Security Guide](https://docs.microsoft.com/en-us/azure/storage/common/storage-security-guide)
- [Terraform Azure Backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure Private Endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
