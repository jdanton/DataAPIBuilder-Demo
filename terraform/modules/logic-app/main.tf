# Logic App Workflow
resource "azurerm_logic_app_workflow" "main" {
  name                = var.logic_app_name
  location            = var.location
  resource_group_name = var.resource_group_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Note: API Connections (azureautomation, azureblob, sql) are typically
# managed separately through the Azure Portal or require complex configuration.
# They have been exported from the existing infrastructure but are not
# recreated here as they require authentication credentials and connection
# strings that should be configured manually or through Azure Portal.
