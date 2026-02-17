variable "sql_server_name" {
  description = "Name of the Azure SQL Server"
  type        = string
}

variable "sql_database_name" {
  description = "Name of the Azure SQL Database"
  type        = string
}

variable "location" {
  description = "Azure region for SQL resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "sql_aad_admin_login" {
  description = "Azure AD admin login name"
  type        = string
}

variable "sql_aad_admin_object_id" {
  description = "Azure AD admin object ID"
  type        = string
}

variable "allowed_client_ips" {
  description = "List of client IP addresses allowed to access SQL Server"
  type        = list(string)
  default     = []
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

variable "schema_file_path" {
  description = "Path to the SQL schema file"
  type        = string
}

variable "deploy_schema" {
  description = "Whether to deploy the database schema"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
