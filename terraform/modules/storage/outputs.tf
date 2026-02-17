output "storage_account_id" {
  description = "Resource ID of the Storage Account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.main.name
}

output "primary_access_key" {
  description = "Primary access key for the Storage Account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_file_endpoint" {
  description = "Primary file endpoint of the Storage Account"
  value       = azurerm_storage_account.main.primary_file_endpoint
}

output "file_share_name" {
  description = "Name of the file share"
  value       = azurerm_storage_share.filestore.name
}

output "file_share_url" {
  description = "URL of the file share"
  value       = azurerm_storage_share.filestore.url
}

output "container_names" {
  description = "List of container names"
  value = [
    azurerm_storage_container.json.name,
    azurerm_storage_container.status.name,
    azurerm_storage_container.parquet.name,
    azurerm_storage_container.powerbi.name,
    azurerm_storage_container.power_bi_backup.name
  ]
}
