variable "location" {
  description = "Azure region for state storage resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group for state storage"
  type        = string
  default     = "terraform-state-rg"
}

variable "storage_account_name" {
  description = "Name of the storage account for Terraform state (must be globally unique)"
  type        = string
  default     = "tfstatedatapibuilder"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-dataapi-eus"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "private_endpoint_subnet_address" {
  description = "Address prefix for the private endpoint subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Purpose     = "Terraform State Storage"
    ManagedBy   = "Terraform Bootstrap"
    Project     = "DataAPIBuilder"
  }
}
