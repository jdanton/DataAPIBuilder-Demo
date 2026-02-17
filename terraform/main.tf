# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Automation Module
module "automation" {
  source = "./modules/automation"

  automation_account_name = var.automation_account_name
  location                = var.location
  resource_group_name     = azurerm_resource_group.main.name
  runbooks_path           = "${path.module}/files/runbooks"
  tags                    = var.tags

  depends_on = [azurerm_resource_group.main]
}

# SQL Module
module "sql" {
  source = "./modules/sql"

  sql_server_name         = var.sql_server_name
  sql_database_name       = var.sql_database_name
  location                = var.location
  resource_group_name     = azurerm_resource_group.main.name
  sql_admin_username      = var.sql_admin_username
  sql_admin_password      = var.sql_admin_password
  sql_aad_admin_login     = var.sql_aad_admin_login
  sql_aad_admin_object_id = var.sql_aad_admin_object_id
  allowed_client_ips      = var.allowed_client_ips
  sql_database_sku        = var.sql_database_sku
  sql_database_max_size_gb = var.sql_database_max_size_gb
  schema_file_path        = "${path.module}/files/sql/schema-cleanup-and-pricing-FINAL.sql"
  deploy_schema           = true
  tags                    = var.tags

  depends_on = [azurerm_resource_group.main]
}

# Storage Module
module "storage" {
  source = "./modules/storage"

  storage_account_name       = var.storage_account_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  account_tier               = var.storage_account_tier
  account_replication_type   = var.storage_account_replication_type
  file_share_quota_gb        = var.file_share_quota_gb
  dab_config_path            = "${path.module}/files/config/dab-config-with-pricing.json"
  tags                       = var.tags

  depends_on = [azurerm_resource_group.main]
}

# Container Registry Module
module "container_registry" {
  source = "./modules/container-registry"

  container_registry_name = var.container_registry_name
  location                = var.location
  resource_group_name     = azurerm_resource_group.main.name
  sku                     = var.container_registry_sku
  tags                    = var.tags

  depends_on = [azurerm_resource_group.main]
}

# Networking Module (Commented out - for future Application Gateway deployment)
# Uncomment this module if you plan to add Application Gateway in front of App Service
# module "networking" {
#   source = "./modules/networking"
#
#   public_ip_name      = var.public_ip_name
#   waf_policy_name     = var.waf_policy_name
#   location            = var.location
#   resource_group_name = azurerm_resource_group.main.name
#   tags                = var.tags
#
#   depends_on = [azurerm_resource_group.main]
# }

# App Service Module
module "app_service" {
  source = "./modules/app-service"

  app_service_plan_name          = var.app_service_plan_name
  web_app_name                   = var.web_app_name
  location                       = var.location
  resource_group_name            = azurerm_resource_group.main.name
  app_service_plan_sku           = var.app_service_plan_sku
  container_registry_login_server = module.container_registry.login_server
  container_registry_username    = module.container_registry.admin_username
  container_registry_password    = module.container_registry.admin_password
  dab_image_tag                  = var.dab_image_tag
  storage_account_name           = module.storage.storage_account_name
  storage_account_access_key     = module.storage.primary_access_key
  file_share_name                = module.storage.file_share_name
  sql_connection_string          = module.sql.connection_string
  tags                           = var.tags

  depends_on = [
    module.container_registry,
    module.storage,
    module.sql
  ]
}

# Logic App Module
module "logic_app" {
  source = "./modules/logic-app"

  logic_app_name      = var.logic_app_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  depends_on = [azurerm_resource_group.main]
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  automation_identity_principal_id = module.automation.identity_principal_id
  storage_account_id               = module.storage.storage_account_id
  subscription_id                  = var.subscription_id

  depends_on = [
    module.automation,
    module.storage
  ]
}
