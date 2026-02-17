# Reader role at subscription scope for Automation Account
resource "azurerm_role_assignment" "automation_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = var.automation_identity_principal_id
}

# Storage Blob Data Contributor role at storage account scope for Automation Account
resource "azurerm_role_assignment" "automation_storage_blob_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.automation_identity_principal_id
}
