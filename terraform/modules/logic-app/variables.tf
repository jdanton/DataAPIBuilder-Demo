variable "logic_app_name" {
  description = "Name of the Logic App"
  type        = string
}

variable "location" {
  description = "Azure region for Logic App resources"
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
