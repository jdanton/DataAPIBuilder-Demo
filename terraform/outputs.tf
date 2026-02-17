output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

output "app_service_url" {
  description = "URL of the Data API Builder web application"
  value       = "https://${module.app_service.default_hostname}"
}

output "rest_api_endpoint" {
  description = "REST API endpoint for Data API Builder"
  value       = "https://${module.app_service.default_hostname}/api"
}

output "graphql_endpoint" {
  description = "GraphQL endpoint for Data API Builder"
  value       = "https://${module.app_service.default_hostname}/graphql"
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = module.sql.server_fqdn
  sensitive   = true
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = module.sql.database_name
}

output "automation_account_id" {
  description = "Resource ID of the Automation Account"
  value       = module.automation.automation_account_id
}

output "automation_account_identity_principal_id" {
  description = "Principal ID of the Automation Account managed identity"
  value       = module.automation.identity_principal_id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.storage.storage_account_name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = module.storage.primary_blob_endpoint
}

output "container_registry_login_server" {
  description = "Login server URL for the Container Registry"
  value       = module.container_registry.login_server
}

output "container_registry_admin_username" {
  description = "Admin username for the Container Registry"
  value       = module.container_registry.admin_username
  sensitive   = true
}

output "public_ip_address" {
  description = "Public IP address for the Application Gateway"
  value       = module.networking.public_ip_address
}

output "logic_app_id" {
  description = "Resource ID of the Logic App"
  value       = module.logic_app.logic_app_id
}
