output "logic_app_id" {
  description = "Resource ID of the Logic App"
  value       = azurerm_logic_app_workflow.main.id
}

output "logic_app_name" {
  description = "Name of the Logic App"
  value       = azurerm_logic_app_workflow.main.name
}

output "identity_principal_id" {
  description = "Principal ID of the Logic App managed identity"
  value       = azurerm_logic_app_workflow.main.identity[0].principal_id
}

output "access_endpoint" {
  description = "Access endpoint for the Logic App"
  value       = azurerm_logic_app_workflow.main.access_endpoint
}
