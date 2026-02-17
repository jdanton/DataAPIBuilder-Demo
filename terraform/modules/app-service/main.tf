# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku

  tags = var.tags
}

# Linux Web App
resource "azurerm_linux_web_app" "main" {
  name                = var.web_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = false

    application_stack {
      docker_image_name   = "azure-databases/data-api-builder:${var.dab_image_tag}"
      docker_registry_url = "https://${var.container_registry_login_server}"
    }

    app_command_line = "dotnet Azure.DataApiBuilder.Service.dll --ConfigFileName /App/config/dab-config.json"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL      = "https://${var.container_registry_login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = var.container_registry_username
    DOCKER_REGISTRY_SERVER_PASSWORD = var.container_registry_password
    DATABASE_CONNECTION_STRING      = var.sql_connection_string
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }

  storage_account {
    name         = "config"
    type         = "AzureFiles"
    account_name = var.storage_account_name
    share_name   = var.file_share_name
    access_key   = var.storage_account_access_key
    mount_path   = "/App/config"
  }

  tags = var.tags
}
