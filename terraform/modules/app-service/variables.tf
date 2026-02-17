variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "web_app_name" {
  description = "Name of the Web App"
  type        = string
}

variable "location" {
  description = "Azure region for app service resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "app_service_plan_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "B1"
}

variable "container_registry_login_server" {
  description = "Login server URL for the Container Registry"
  type        = string
}

variable "container_registry_username" {
  description = "Admin username for the Container Registry"
  type        = string
  sensitive   = true
}

variable "container_registry_password" {
  description = "Admin password for the Container Registry"
  type        = string
  sensitive   = true
}

variable "dab_image_tag" {
  description = "Tag for the Data API Builder container image"
  type        = string
  default     = "latest"
}

variable "storage_account_name" {
  description = "Name of the Storage Account"
  type        = string
}

variable "storage_account_access_key" {
  description = "Access key for the Storage Account"
  type        = string
  sensitive   = true
}

variable "file_share_name" {
  description = "Name of the file share"
  type        = string
}

variable "sql_connection_string" {
  description = "SQL Server connection string"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
