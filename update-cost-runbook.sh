#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Update Azure-Cost-Management Runbook ===${NC}"
echo ""

# Configuration
RESOURCE_GROUP="DataAPIBuilder"
AUTOMATION_ACCOUNT="VMSizes"
RUNBOOK_NAME="Azure-Cost-Management"
RUNBOOK_FILE="runbooks/Azure-Cost-Management.ps1"

# Check if runbook file exists
if [ ! -f "$RUNBOOK_FILE" ]; then
    echo "Error: Runbook file not found: $RUNBOOK_FILE"
    exit 1
fi

# Check Azure CLI login
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure CLI"
    echo "Please run: az login"
    exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ Connected to Azure subscription: ${SUBSCRIPTION_NAME}${NC}"
echo ""

# Update runbook content
echo -e "${YELLOW}Updating runbook content...${NC}"
az automation runbook replace-content \
    --resource-group "$RESOURCE_GROUP" \
    --automation-account-name "$AUTOMATION_ACCOUNT" \
    --name "$RUNBOOK_NAME" \
    --content "@$RUNBOOK_FILE"

echo ""
echo -e "${GREEN}✓ Runbook content updated successfully${NC}"
echo ""

# Optional: Publish the runbook
read -p "Do you want to publish the runbook now? (yes/no): " -r
echo

if [[ $REPLY =~ ^[Yy]es$ ]]; then
    echo -e "${YELLOW}Publishing runbook...${NC}"
    az automation runbook publish \
        --resource-group "$RESOURCE_GROUP" \
        --automation-account-name "$AUTOMATION_ACCOUNT" \
        --name "$RUNBOOK_NAME"

    echo ""
    echo -e "${GREEN}✓ Runbook published${NC}"
else
    echo -e "${YELLOW}Runbook updated but not published (still in Draft state)${NC}"
    echo "To publish later, run:"
    echo "az automation runbook publish --resource-group $RESOURCE_GROUP --automation-account-name $AUTOMATION_ACCOUNT --name $RUNBOOK_NAME"
fi

echo ""
echo -e "${GREEN}=== Update Complete ===${NC}"
echo ""
echo "Summary:"
echo "  Resource Group:      $RESOURCE_GROUP"
echo "  Automation Account:  $AUTOMATION_ACCOUNT"
echo "  Runbook:             $RUNBOOK_NAME"
echo "  Scope:               VMs ONLY"
echo ""
echo "The runbook will run on its next scheduled execution:"
echo "  Schedule: Nightly VM Cost Analysis (Daily)"
echo ""
echo "To test immediately, run:"
echo "az automation runbook start --resource-group $RESOURCE_GROUP --automation-account-name $AUTOMATION_ACCOUNT --name $RUNBOOK_NAME"
