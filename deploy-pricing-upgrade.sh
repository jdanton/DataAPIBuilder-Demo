#!/bin/bash
#
# VMSizes Database - Pricing Feature Upgrade Deployment Script
# Version: 2.0
# Date: 2026-02-16
#
# This script automates the deployment of schema cleanup and Azure pricing integration
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - sqlpackage installed (for database backup)
#   - sqlcmd installed (for running SQL scripts)
#   - Docker installed (for container rebuild)
#   - Appropriate Azure permissions
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="DataAPIBuilder"
SQL_SERVER="dataapibuilderdemo"
DATABASE="VMSizes"
AUTOMATION_ACCOUNT="VMSizes"
WEBAPP_NAME="vmsizesazure"
ACR_NAME="dataapibuilderdemojd"
LOCATION="eastus"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/sql"
RUNBOOKS_DIR="${SCRIPT_DIR}/runbooks"
BACKUP_DIR="${SCRIPT_DIR}/backups"
LOG_FILE="${SCRIPT_DIR}/deployment-$(date +%Y%m%d-%H%M%S).log"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Command line flags
SKIP_SCHEMA=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-schema)
            SKIP_SCHEMA=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-schema    Skip database schema upgrade (use if already upgraded manually)"
            echo "  --help, -h       Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() {
    log "INFO" "${BLUE}$@${NC}"
}

success() {
    log "SUCCESS" "${GREEN}✓ $@${NC}"
}

warn() {
    log "WARN" "${YELLOW}⚠ $@${NC}"
}

error() {
    log "ERROR" "${RED}✗ $@${NC}"
}

# Print banner
print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   VMSizes Database - Pricing Feature Upgrade                 ║
║   Version 2.0                                                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    local missing=0

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        error "Azure CLI not found. Install from: https://aka.ms/azure-cli"
        missing=1
    else
        success "Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv)"
    fi

    # Check sqlpackage
    if ! command -v sqlpackage &> /dev/null; then
        warn "sqlpackage not found. Database backup will be skipped."
        warn "Install from: https://aka.ms/sqlpackage"
    else
        success "sqlpackage found: $(sqlpackage /version)"
    fi

    # Check sqlcmd
    if ! command -v sqlcmd &> /dev/null; then
        error "sqlcmd not found. Install SQL command-line tools."
        missing=1
    else
        success "sqlcmd found"
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        warn "Docker not found. Container deployment will be skipped."
    else
        success "Docker found: $(docker --version)"
    fi

    # Check Azure login
    if ! az account show &> /dev/null; then
        error "Not logged into Azure. Run: az login"
        missing=1
    else
        local subscription=$(az account show --query name -o tsv)
        success "Logged into Azure: ${subscription}"
    fi

    if [ $missing -ne 0 ]; then
        error "Prerequisites not met. Aborting."
        exit 1
    fi

    success "All prerequisites met"
}

# Confirm deployment
confirm_deployment() {
    echo ""
    info "Deployment Configuration:"
    echo "  Resource Group:      ${RESOURCE_GROUP}"
    echo "  SQL Server:          ${SQL_SERVER}.database.windows.net"
    echo "  Database:            ${DATABASE}"
    echo "  Automation Account:  ${AUTOMATION_ACCOUNT}"
    echo "  Web App:             ${WEBAPP_NAME}"
    echo "  Container Registry:  ${ACR_NAME}"
    echo "  Location:            ${LOCATION}"
    echo ""
    info "Log file: ${LOG_FILE}"
    echo ""

    read -p "$(echo -e ${YELLOW}Do you want to proceed with the upgrade? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Deployment cancelled by user"
        exit 0
    fi
}

# Step 1: Backup database
backup_database() {
    info "Step 1: Backing up database..."

    if ! command -v sqlpackage &> /dev/null; then
        warn "Skipping database backup (sqlpackage not installed)"
        return 0
    fi

    local backup_file="${BACKUP_DIR}/${DATABASE}-backup-$(date +%Y%m%d-%H%M%S).dacpac"

    info "Getting Azure SQL access token..."
    local token=$(az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv)

    info "Extracting database to: ${backup_file}"

    if sqlpackage /Action:Extract \
        /SourceServerName:"${SQL_SERVER}.database.windows.net" \
        /SourceDatabaseName:"${DATABASE}" \
        /TargetFile:"${backup_file}" \
        /AccessToken:"${token}" \
        /p:ExtractAllTableData=False \
        /p:VerifyExtraction=True >> "${LOG_FILE}" 2>&1; then
        success "Database backed up successfully"
        info "Backup location: ${backup_file}"
        echo "${backup_file}" > "${BACKUP_DIR}/latest-backup.txt"
    else
        error "Database backup failed. Check log: ${LOG_FILE}"
        warn "Continuing anyway (existing data should be safe with MERGE/UPSERT operations)"
    fi
}

# Step 2: Run schema upgrade
upgrade_schema() {
    info "Step 2: Upgrading database schema..."

    # Check if schema is already upgraded
    info "Checking if schema is already upgraded..."

    local schema_exists=$(az sql db query \
        --server "${SQL_SERVER}" \
        --database "${DATABASE}" \
        --query-text "SELECT CASE WHEN EXISTS (SELECT * FROM sys.tables WHERE name = 'VMSizes') AND EXISTS (SELECT * FROM sys.tables WHERE name = 'VMPricing') THEN 'YES' ELSE 'NO' END" \
        2>/dev/null | grep -i "YES" > /dev/null && echo "1" || echo "0")

    if [[ "${schema_exists}" == "1" ]]; then
        success "✓ Schema already upgraded (VMSizes and VMPricing tables exist)"
        info "Skipping schema upgrade step"
        return 0
    fi

    local schema_file="${SQL_DIR}/schema-cleanup-and-pricing-FINAL.sql"

    if [ ! -f "${schema_file}" ]; then
        error "Schema file not found: ${schema_file}"
        error "Please run the SQL script manually in Azure Portal Query Editor"
        error "See QUICK-FIX-AUTH.md for instructions"
        exit 1
    fi

    warn "⚠ Schema not yet upgraded. Attempting automated upgrade..."
    warn "Note: sqlcmd authentication may fail on macOS"
    info "If this fails, run the SQL script manually in Azure Portal Query Editor"
    info "See: ${schema_file}"

    info "Running SQL upgrade script..."
    info "This may take several minutes..."

    if sqlcmd -S "${SQL_SERVER}.database.windows.net" \
        -d "${DATABASE}" \
        -G \
        -i "${schema_file}" \
        -o "${BACKUP_DIR}/schema-upgrade-output.log" 2>&1; then
        success "Schema upgraded successfully"
    else
        error "Schema upgrade failed. Check: ${BACKUP_DIR}/schema-upgrade-output.log"
        warn "You can run the SQL script manually in Azure Portal and then re-run this deployment script"
        warn "See: QUICK-FIX-AUTH.md for instructions"
        exit 1
    fi
}

# Step 3: Upload runbooks
upload_runbooks() {
    info "Step 3: Uploading automation runbooks..."

    local runbooks=(
        "GetData-v2:PowerShell72"
        "GetPricingData:PowerShell72"
    )

    for runbook_info in "${runbooks[@]}"; do
        IFS=':' read -r runbook_name runbook_type <<< "${runbook_info}"
        local runbook_file="${RUNBOOKS_DIR}/${runbook_name}.ps1"

        if [ ! -f "${runbook_file}" ]; then
            error "Runbook file not found: ${runbook_file}"
            continue
        fi

        info "Uploading runbook: ${runbook_name}..."

        # Check if runbook exists
        if az automation runbook show \
            --automation-account-name "${AUTOMATION_ACCOUNT}" \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${runbook_name}" &> /dev/null; then
            info "Runbook ${runbook_name} exists, updating..."
        else
            info "Creating new runbook: ${runbook_name}..."
            az automation runbook create \
                --automation-account-name "${AUTOMATION_ACCOUNT}" \
                --resource-group "${RESOURCE_GROUP}" \
                --name "${runbook_name}" \
                --type "${runbook_type}" \
                --location "${LOCATION}" >> "${LOG_FILE}" 2>&1
        fi

        # Upload content
        info "Replacing content for ${runbook_name}..."
        az automation runbook replace-content \
            --automation-account-name "${AUTOMATION_ACCOUNT}" \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${runbook_name}" \
            --content "@${runbook_file}" >> "${LOG_FILE}" 2>&1

        # Publish
        info "Publishing ${runbook_name}..."
        az automation runbook publish \
            --automation-account-name "${AUTOMATION_ACCOUNT}" \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${runbook_name}" >> "${LOG_FILE}" 2>&1

        success "Runbook ${runbook_name} uploaded and published"
    done
}

# Step 4: Run initial data collection
run_data_collection() {
    info "Step 4: Running initial data collection..."

    read -p "$(echo -e ${YELLOW}Do you want to run data collection now? (This may take 30-60 minutes) [Y/n]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warn "Skipping data collection. Run manually later."
        return 0
    fi

    # Run VM data collection
    info "Starting GetData-v2 runbook..."
    local vm_job=$(az automation runbook start \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --name "GetData-v2" \
        --query name -o tsv)

    success "VM data collection job started: ${vm_job}"
    info "Monitor at: https://portal.azure.com"

    # Wait option
    read -p "$(echo -e ${YELLOW}Wait for VM collection to complete before starting pricing? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Waiting for VM data collection to complete..."
        info "This may take 30-60 minutes. You can press Ctrl+C to skip waiting."

        while true; do
            local status=$(az automation job show \
                --automation-account-name "${AUTOMATION_ACCOUNT}" \
                --resource-group "${RESOURCE_GROUP}" \
                --job-name "${vm_job}" \
                --query status -o tsv 2>/dev/null || echo "Unknown")

            if [[ "${status}" == "Completed" ]]; then
                success "VM data collection completed"
                break
            elif [[ "${status}" == "Failed" ]]; then
                error "VM data collection failed"
                break
            else
                info "Status: ${status}... (waiting 30s)"
                sleep 30
            fi
        done
    fi

    # Run pricing collection
    info "Starting GetPricingData runbook..."
    local pricing_job=$(az automation runbook start \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --name "GetPricingData" \
        --query name -o tsv)

    success "Pricing data collection job started: ${pricing_job}"
}

# Step 5: Update Data API Builder configuration
update_api_config() {
    info "Step 5: Updating Data API Builder configuration..."

    local config_file="${SCRIPT_DIR}/dab-config-with-pricing.json"

    if [ ! -f "${config_file}" ]; then
        error "Configuration file not found: ${config_file}"
        return 1
    fi

    # Backup current config if it exists
    if [ -f "${SCRIPT_DIR}/dab-config.json" ]; then
        cp "${SCRIPT_DIR}/dab-config.json" "${BACKUP_DIR}/dab-config-backup-$(date +%Y%m%d-%H%M%S).json"
        info "Backed up existing configuration"
    fi

    # Copy new config
    cp "${config_file}" "${SCRIPT_DIR}/dab-config.json"
    success "Updated Data API Builder configuration"
}

# Step 6: Rebuild and deploy container
deploy_container() {
    info "Step 6: Deploying updated container..."

    if ! command -v docker &> /dev/null; then
        warn "Docker not found. Skipping container deployment."
        info "Manually deploy using: docker build && docker push && az webapp restart"
        return 0
    fi

    read -p "$(echo -e ${YELLOW}Do you want to rebuild and deploy the container? [Y/n]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warn "Skipping container deployment"
        return 0
    fi

    # Login to ACR
    info "Logging into Azure Container Registry..."
    az acr login --name "${ACR_NAME}" >> "${LOG_FILE}" 2>&1

    # Build image
    local image_tag="v2.0-$(date +%Y%m%d-%H%M%S)"
    local image_name="${ACR_NAME}.azurecr.io/azure-databases/data-api-builder"

    info "Building container image: ${image_name}:${image_tag}..."
    docker build -f "${SCRIPT_DIR}/Dockerfile.alternative" \
        -t "${image_name}:${image_tag}" \
        -t "${image_name}:latest" \
        "${SCRIPT_DIR}" >> "${LOG_FILE}" 2>&1

    success "Container built successfully"

    # Push images
    info "Pushing images to ACR..."
    docker push "${image_name}:${image_tag}" >> "${LOG_FILE}" 2>&1
    docker push "${image_name}:latest" >> "${LOG_FILE}" 2>&1

    success "Images pushed to registry"

    # Update App Service
    info "Updating App Service to use new image..."
    az webapp config container set \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${WEBAPP_NAME}" \
        --docker-custom-image-name "${image_name}:${image_tag}" \
        --docker-registry-server-url "https://${ACR_NAME}.azurecr.io" >> "${LOG_FILE}" 2>&1

    # Restart app
    info "Restarting App Service..."
    az webapp restart \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${WEBAPP_NAME}" >> "${LOG_FILE}" 2>&1

    success "App Service updated and restarted"
}

# Step 7: Setup schedules
setup_schedules() {
    info "Step 7: Setting up automation schedules..."

    read -p "$(echo -e ${YELLOW}Do you want to setup automated schedules? [Y/n]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warn "Skipping schedule setup"
        return 0
    fi

    # VM data collection - Daily at 2 AM UTC
    info "Creating daily VM data collection schedule..."
    local vm_schedule="DailyVMDataCollection-v2"
    local start_time=$(date -u -d "tomorrow 02:00" '+%Y-%m-%dT%H:%M:%S+00:00' 2>/dev/null || date -u -v+1d -v2H -v0M -v0S '+%Y-%m-%dT%H:%M:%S+00:00')

    # Delete old schedule if exists
    az automation schedule delete \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${vm_schedule}" --yes &> /dev/null || true

    az automation schedule create \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${vm_schedule}" \
        --frequency "Day" \
        --interval 1 \
        --start-time "${start_time}" \
        --time-zone "UTC" >> "${LOG_FILE}" 2>&1

    az automation job-schedule create \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --runbook-name "GetData-v2" \
        --schedule-name "${vm_schedule}" >> "${LOG_FILE}" 2>&1

    success "Daily VM data collection scheduled"

    # Pricing collection - Weekly on Sunday at 3 AM UTC
    info "Creating weekly pricing collection schedule..."
    local pricing_schedule="WeeklyPricingCollection"

    # Delete old schedule if exists
    az automation schedule delete \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${pricing_schedule}" --yes &> /dev/null || true

    az automation schedule create \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${pricing_schedule}" \
        --frequency "Week" \
        --interval 1 \
        --start-time "${start_time}" \
        --time-zone "UTC" >> "${LOG_FILE}" 2>&1

    az automation job-schedule create \
        --automation-account-name "${AUTOMATION_ACCOUNT}" \
        --resource-group "${RESOURCE_GROUP}" \
        --runbook-name "GetPricingData" \
        --schedule-name "${pricing_schedule}" >> "${LOG_FILE}" 2>&1

    success "Weekly pricing collection scheduled"
}

# Step 8: Test deployment
test_deployment() {
    info "Step 8: Testing deployment..."

    local api_url="https://${WEBAPP_NAME}.azurewebsites.net"

    info "Waiting for App Service to be ready..."
    sleep 10

    # Test basic endpoint
    info "Testing /api/vmsizes-pricing endpoint..."
    if curl -f -s "${api_url}/api/vmsizes-pricing?\$top=1" > /dev/null 2>&1; then
        success "API endpoint responding"
    else
        warn "API endpoint not responding yet. May need more time to start."
    fi

    # Test GraphQL
    info "Testing /graphql endpoint..."
    if curl -f -s -X POST "${api_url}/graphql" \
        -H "Content-Type: application/json" \
        -d '{"query":"{ __schema { types { name } } }"}' > /dev/null 2>&1; then
        success "GraphQL endpoint responding"
    else
        warn "GraphQL endpoint not responding yet"
    fi

    info "API URL: ${api_url}"
    info "Test in browser: ${api_url}/api/regions"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ✓ Deployment Complete!                                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    info "Deployment Summary:"
    echo "  ✓ Database schema upgraded"
    echo "  ✓ Runbooks uploaded (GetData-v2, GetPricingData)"
    echo "  ✓ Data collection initiated"
    echo "  ✓ API configuration updated"
    echo "  ✓ Container deployed (if applicable)"
    echo "  ✓ Schedules configured (if applicable)"
    echo ""
    info "Next Steps:"
    echo "  1. Monitor runbook execution in Azure Portal"
    echo "  2. Test API endpoints: https://${WEBAPP_NAME}.azurewebsites.net/api/vmsizes-pricing"
    echo "  3. Review documentation: SCHEMA-UPGRADE-GUIDE.md"
    echo "  4. Check API examples: API-EXAMPLES-WITH-PRICING.md"
    echo ""
    info "Rollback Information:"
    if [ -f "${BACKUP_DIR}/latest-backup.txt" ]; then
        local backup_file=$(cat "${BACKUP_DIR}/latest-backup.txt")
        echo "  Database backup: ${backup_file}"
    fi
    echo "  Deployment log: ${LOG_FILE}"
    echo ""
    success "Upgrade completed successfully!"
}

# Rollback function
rollback() {
    error "Deployment failed or interrupted"
    warn "To rollback:"

    if [ -f "${BACKUP_DIR}/latest-backup.txt" ]; then
        local backup_file=$(cat "${BACKUP_DIR}/latest-backup.txt")
        echo "  1. Restore database:"
        echo "     sqlpackage /Action:Publish /SourceFile:${backup_file} \\"
        echo "       /TargetServerName:${SQL_SERVER}.database.windows.net \\"
        echo "       /TargetDatabaseName:${DATABASE}"
    fi

    echo "  2. Check logs: ${LOG_FILE}"
    echo "  3. Review: SCHEMA-UPGRADE-GUIDE.md (Rollback section)"
}

# Trap errors
trap rollback ERR INT TERM

# Main execution
main() {
    print_banner
    check_prerequisites
    confirm_deployment

    info "Starting deployment..."
    echo ""

    backup_database

    if [ "${SKIP_SCHEMA}" = true ]; then
        success "✓ Skipping schema upgrade (--skip-schema flag provided)"
    else
        upgrade_schema
    fi

    upload_runbooks
    run_data_collection
    update_api_config
    deploy_container
    setup_schedules
    test_deployment

    print_summary
}

# Run main function
main "$@"
