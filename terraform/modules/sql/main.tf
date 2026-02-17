# SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = var.sql_server_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  azuread_administrator {
    login_username = var.sql_aad_admin_login
    object_id      = var.sql_aad_admin_object_id
  }

  identity {
    type = "SystemAssigned"
  }

  public_network_access_enabled = true

  tags = var.tags
}

# SQL Database
resource "azurerm_mssql_database" "main" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.main.id
  sku_name  = var.sql_database_sku
  max_size_gb = var.sql_database_max_size_gb

  storage_account_type = "Local"

  tags = var.tags
}

# Firewall Rules
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "client_ips" {
  for_each = { for idx, ip in var.allowed_client_ips : idx => ip }

  name             = "ClientIP-${each.key}"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = each.value
  end_ip_address   = each.value
}

# Schema Deployment
resource "null_resource" "deploy_schema" {
  count = var.deploy_schema ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      az sql db query \
        --server ${azurerm_mssql_server.main.name} \
        --database ${var.sql_database_name} \
        --auth-mode SqlPassword \
        --name ${var.sql_admin_username} \
        --output none \
        --query-file ${var.schema_file_path}
    EOT

    environment = {
      SQLCMDPASSWORD = var.sql_admin_password
    }
  }

  triggers = {
    schema_hash = filemd5(var.schema_file_path)
    database_id = azurerm_mssql_database.main.id
  }

  depends_on = [
    azurerm_mssql_database.main,
    azurerm_mssql_firewall_rule.allow_azure_services
  ]
}
