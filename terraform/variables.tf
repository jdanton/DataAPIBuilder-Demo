variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, or prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "DataAPIBuilder"
}

variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  default     = "CloudSA090090fe"
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "allowed_client_ips" {
  description = "List of client IP addresses allowed to access SQL Server"
  type        = list(string)
  default     = []
}

variable "subscription_id" {
  description = "Azure subscription ID for role assignments"
  type        = string
}

variable "sql_aad_admin_login" {
  description = "Azure AD admin login name for SQL Server"
  type        = string
  default     = "Joey"
}

variable "sql_aad_admin_object_id" {
  description = "Azure AD admin object ID for SQL Server"
  type        = string
}

variable "automation_account_name" {
  description = "Name of the Azure Automation Account"
  type        = string
  default     = "VMSizes"
}

variable "sql_server_name" {
  description = "Name of the Azure SQL Server"
  type        = string
  default     = "dataapibuilderdemo"
}

variable "sql_database_name" {
  description = "Name of the Azure SQL Database"
  type        = string
  default     = "VMSizes"
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account"
  type        = string
  default     = "datapibuilderdemo"
}

variable "container_registry_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "dataapibuilderdemojd"
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "ASP-DataAPIBuilder-a8e9"
}

variable "web_app_name" {
  description = "Name of the Web App"
  type        = string
  default     = "vmsizesazure"
}

variable "logic_app_name" {
  description = "Name of the Logic App"
  type        = string
  default     = "VMSizesLogicApp"
}

# Networking variables (commented out - for future Application Gateway)
# variable "public_ip_name" {
#   description = "Name of the Public IP"
#   type        = string
#   default     = "appgw-pip-datapibuilder"
# }

# variable "waf_policy_name" {
#   description = "Name of the WAF Policy"
#   type        = string
#   default     = "DemoAppGW-WAF-Policy"
# }

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "DataAPIBuilder"
  }
}

variable "dab_image_tag" {
  description = "Tag for the Data API Builder container image"
  type        = string
  default     = "latest"
}

variable "sql_database_sku" {
  description = "SKU for SQL Database"
  type        = string
  default     = "S0"
}

variable "sql_database_max_size_gb" {
  description = "Maximum size in GB for SQL Database"
  type        = number
  default     = 250
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "file_share_quota_gb" {
  description = "Quota in GB for the file share"
  type        = number
  default     = 10
}

variable "app_service_plan_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "B1"
}

variable "container_registry_sku" {
  description = "SKU for Container Registry"
  type        = string
  default     = "Standard"
}
