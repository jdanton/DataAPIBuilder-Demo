# Resource Group for Terraform State Storage
resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "state" {
  name                = var.vnet_name
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.state.name
  virtual_network_name = azurerm_virtual_network.state.name
  address_prefixes     = var.private_endpoint_subnet_address
}

# Storage Account for Terraform State
resource "azurerm_storage_account" "state" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant for state files
  account_kind             = "StorageV2"

  min_tls_version = "TLS1_2"

  # Enable blob versioning for state file protection
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  # Disable public network access - access only via private endpoint
  public_network_access_enabled = false

  # Enable infrastructure encryption
  infrastructure_encryption_enabled = true

  tags = var.tags
}

# Blob Container for Terraform State
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

# Private DNS Zone for Blob Storage
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.state.name
  tags                = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.vnet_name}-link"
  resource_group_name   = azurerm_resource_group.state.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.state.id
  registration_enabled  = false
  tags                  = var.tags
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "state_storage" {
  name                = "pe-${var.storage_account_name}"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-${var.storage_account_name}"
    private_connection_resource_id = azurerm_storage_account.state.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = var.tags
}

# Resource Lock to prevent accidental deletion
resource "azurerm_management_lock" "state_storage" {
  name       = "state-storage-lock"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of Terraform state storage"
}
