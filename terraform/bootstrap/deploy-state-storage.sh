#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Terraform State Storage Bootstrap ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    exit 1
fi

# Check Azure login
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    echo "Please run: az login"
    exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✓ Connected to Azure subscription: ${SUBSCRIPTION_NAME}${NC}"
echo -e "  Subscription ID: ${SUBSCRIPTION_ID}"
echo ""

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Validate configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan deployment
echo -e "${YELLOW}Planning infrastructure...${NC}"
terraform plan -out=tfplan

# Ask for confirmation
echo ""
echo -e "${YELLOW}Ready to deploy Terraform state storage infrastructure.${NC}"
echo "This will create:"
echo "  - Resource Group: terraform-state-rg"
echo "  - Virtual Network: vnet-dataapi-eus (10.0.0.0/16)"
echo "  - Subnet: snet-private-endpoints (10.0.1.0/24)"
echo "  - Storage Account: tfstatedatapibuilder (with private endpoint)"
echo "  - Private DNS Zone: privatelink.blob.core.windows.net"
echo "  - Management Lock: CanNotDelete"
echo ""
read -p "Do you want to proceed? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    rm -f tfplan
    exit 0
fi

# Apply configuration
echo -e "${YELLOW}Deploying infrastructure...${NC}"
terraform apply tfplan

# Clean up plan file
rm -f tfplan

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""

# Output backend configuration
echo -e "${YELLOW}Backend Configuration:${NC}"
echo "Copy the following to your main terraform/backend.tf file:"
echo ""
terraform output -raw backend_config
echo ""
echo ""

# Output next steps
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Copy the backend configuration above to ../backend.tf"
echo "2. Uncomment the terraform backend block in ../backend.tf"
echo "3. Run: cd .. && terraform init -reconfigure"
echo ""

# Output connection information
echo -e "${YELLOW}=== Important: Network Access ===${NC}"
echo "The storage account is configured with PRIVATE ENDPOINT ONLY."
echo "To access Terraform state, you must be connected to the VNet:"
echo ""
echo "Options:"
echo "  1. Set up Point-to-Site VPN to vnet-dataapi-eus"
echo "  2. Use Azure Bastion or Jump Box in the VNet"
echo "  3. Use Azure Cloud Shell (may require VNet integration)"
echo ""
echo -e "${RED}Note: Public network access is DISABLED for security${NC}"
echo ""

# Display resource information
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
VNET_NAME=$(terraform output -raw vnet_name)

echo -e "${GREEN}=== Deployed Resources ===${NC}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Storage Account: ${STORAGE_ACCOUNT}"
echo "VNet: ${VNET_NAME}"
echo "Container: tfstate"
echo ""

echo -e "${GREEN}Deployment successful!${NC}"
