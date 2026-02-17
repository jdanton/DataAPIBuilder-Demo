# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = "StorageV2"

  # Enable Hierarchical Namespace for Data Lake Gen2
  is_hns_enabled = true

  # Enable blob versioning
  blob_properties {
    versioning_enabled = true
  }

  tags = var.tags
}

# Blob Containers
resource "azurerm_storage_container" "json" {
  name                  = "json"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "status" {
  name                  = "status"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "parquet" {
  name                  = "parquet"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "powerbi" {
  name                  = "powerbi"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "power_bi_backup" {
  name                  = "power-bi-backup"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# File Share
resource "azurerm_storage_share" "filestore" {
  name                 = "filestore"
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.file_share_quota_gb
  access_tier          = "Hot"
}

# Upload DAB Config to File Share
resource "null_resource" "upload_dab_config" {
  provisioner "local-exec" {
    command = <<-EOT
      az storage file upload \
        --account-name ${azurerm_storage_account.main.name} \
        --account-key ${azurerm_storage_account.main.primary_access_key} \
        --share-name filestore \
        --source ${var.dab_config_path} \
        --path dab-config.json
    EOT
  }

  triggers = {
    config_hash = filemd5(var.dab_config_path)
    share_id    = azurerm_storage_share.filestore.id
  }

  depends_on = [azurerm_storage_share.filestore]
}
