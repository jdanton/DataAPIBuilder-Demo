# Automation Account
resource "azurerm_automation_account" "main" {
  name                = var.automation_account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  public_network_access_enabled = true

  tags = var.tags
}

# PowerShell 7.2 Modules
resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts"
  }
}

resource "azurerm_automation_module" "az_compute" {
  name                    = "Az.Compute"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Compute"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_storage" {
  name                    = "Az.Storage"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Storage"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_sql" {
  name                    = "Az.Sql"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Sql"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

# Runbooks
resource "azurerm_automation_runbook" "getdata" {
  name                    = "GetData"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell72"

  content = file("${var.runbooks_path}/GetData.ps1")

  tags = var.tags

  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_storage,
    azurerm_automation_module.az_sql
  ]
}

resource "azurerm_automation_runbook" "getdata_v2" {
  name                    = "GetData-v2"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell72"

  content = file("${var.runbooks_path}/GetData-v2.ps1")

  tags = var.tags

  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_storage,
    azurerm_automation_module.az_sql
  ]
}

resource "azurerm_automation_runbook" "getpricingdata" {
  name                    = "GetPricingData"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell72"

  content = file("${var.runbooks_path}/GetPricingData.ps1")

  tags = var.tags

  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_storage,
    azurerm_automation_module.az_sql
  ]
}

resource "azurerm_automation_runbook" "cleanup" {
  name                    = "Cleanup"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell72"

  content = file("${var.runbooks_path}/Cleanup.ps1")

  tags = var.tags

  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_storage,
    azurerm_automation_module.az_sql
  ]
}

resource "azurerm_automation_runbook" "azure_cost_management" {
  name                    = "Azure-Cost-Management"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell72"

  content = file("${var.runbooks_path}/Azure-Cost-Management.ps1")

  tags = var.tags

  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_storage,
    azurerm_automation_module.az_sql
  ]
}

resource "azurerm_automation_runbook" "tutorial_with_identity" {
  name                    = "AzureAutomationTutorialWithIdentity"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell72"

  content = file("${var.runbooks_path}/AzureAutomationTutorialWithIdentity.ps1")

  tags = var.tags

  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_storage,
    azurerm_automation_module.az_sql
  ]
}

# Schedules
resource "azurerm_automation_schedule" "daily_vm_collection" {
  name                    = "Daily VM Collection"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/New_York"
  start_time              = timeadd(timestamp(), "24h") # Start 24 hours from now
  description             = "Daily collection of VM sizes and data"
}

resource "azurerm_automation_schedule" "weekly_pricing" {
  name                    = "Weekly Pricing Update"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Week"
  interval                = 1
  timezone                = "America/New_York"
  start_time              = timeadd(timestamp(), "24h") # Start 24 hours from now
  description             = "Weekly update of Azure pricing data"
  week_days               = ["Sunday"]
}

resource "azurerm_automation_schedule" "nightly_cost_management" {
  name                    = "Nightly Cost Management"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/New_York"
  start_time              = timeadd(timestamp(), "24h") # Start 24 hours from now
  description             = "Nightly cost management reporting"
}

# Job Schedules (Link runbooks to schedules)
resource "azurerm_automation_job_schedule" "getdata_v2_daily" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  runbook_name            = azurerm_automation_runbook.getdata_v2.name
  schedule_name           = azurerm_automation_schedule.daily_vm_collection.name
}

resource "azurerm_automation_job_schedule" "pricing_weekly" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  runbook_name            = azurerm_automation_runbook.getpricingdata.name
  schedule_name           = azurerm_automation_schedule.weekly_pricing.name
}

resource "azurerm_automation_job_schedule" "cost_management_nightly" {
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name
  runbook_name            = azurerm_automation_runbook.azure_cost_management.name
  schedule_name           = azurerm_automation_schedule.nightly_cost_management.name
}
