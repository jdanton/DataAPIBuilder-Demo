output "automation_account_id" {
  description = "Resource ID of the Automation Account"
  value       = azurerm_automation_account.main.id
}

output "automation_account_name" {
  description = "Name of the Automation Account"
  value       = azurerm_automation_account.main.name
}

output "identity_principal_id" {
  description = "Principal ID of the Automation Account managed identity"
  value       = azurerm_automation_account.main.identity[0].principal_id
}

output "identity_tenant_id" {
  description = "Tenant ID of the Automation Account managed identity"
  value       = azurerm_automation_account.main.identity[0].tenant_id
}

output "runbook_names" {
  description = "List of deployed runbook names"
  value = [
    azurerm_automation_runbook.getdata.name,
    azurerm_automation_runbook.getdata_v2.name,
    azurerm_automation_runbook.getpricingdata.name,
    azurerm_automation_runbook.cleanup.name,
    azurerm_automation_runbook.azure_cost_management.name,
    azurerm_automation_runbook.tutorial_with_identity.name
  ]
}
