# Remote State Backend Configuration
#
# This backend uses a private endpoint-secured storage account.
# The storage account is NOT accessible from public internet.
#
# To create the backend storage:
#
# cd bootstrap
# ./deploy-state-storage.sh
#
# This will create:
#   - Resource Group: terraform-state-rg
#   - VNet: vnet-dataapi-eus (with private endpoint subnet)
#   - Storage Account: tfstatedatapibuilder (GRS, private endpoint only)
#   - Private DNS Zone: privatelink.blob.core.windows.net
#
# IMPORTANT: You must be connected to vnet-dataapi-eus via VPN or Bastion
# to access the state storage.
#
# After deploying bootstrap, uncomment the terraform block below and run:
# terraform init -reconfigure

# terraform {
#   backend "azurerm" {
#     resource_group_name  = "terraform-state-rg"
#     storage_account_name = "tfstatedatapibuilder"
#     container_name       = "tfstate"
#     key                  = "dataapi/terraform.tfstate"
#   }
# }
