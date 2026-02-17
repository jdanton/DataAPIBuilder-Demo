variable "automation_account_name" {
  description = "Name of the Azure Automation Account"
  type        = string
}

variable "location" {
  description = "Azure region for the automation account"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "runbooks_path" {
  description = "Path to runbook files"
  type        = string
}
