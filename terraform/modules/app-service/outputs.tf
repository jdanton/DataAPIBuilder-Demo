output "app_service_plan_id" {
  description = "Resource ID of the App Service Plan"
  value       = azurerm_service_plan.main.id
}

output "app_service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.main.name
}

output "web_app_id" {
  description = "Resource ID of the Web App"
  value       = azurerm_linux_web_app.main.id
}

output "web_app_name" {
  description = "Name of the Web App"
  value       = azurerm_linux_web_app.main.name
}

output "default_hostname" {
  description = "Default hostname of the Web App"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "outbound_ip_addresses" {
  description = "Outbound IP addresses of the Web App"
  value       = azurerm_linux_web_app.main.outbound_ip_addresses
}

output "possible_outbound_ip_addresses" {
  description = "Possible outbound IP addresses of the Web App"
  value       = azurerm_linux_web_app.main.possible_outbound_ip_addresses
}
