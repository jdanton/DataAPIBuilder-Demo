variable "storage_account_name" {
  description = "Name of the Azure Storage Account"
  type        = string
}

variable "location" {
  description = "Azure region for storage resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "file_share_quota_gb" {
  description = "Quota in GB for the file share"
  type        = number
  default     = 10
}

variable "dab_config_path" {
  description = "Path to the DAB configuration file"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
