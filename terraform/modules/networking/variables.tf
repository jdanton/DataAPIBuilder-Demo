variable "public_ip_name" {
  description = "Name of the Public IP"
  type        = string
}

variable "waf_policy_name" {
  description = "Name of the WAF Policy"
  type        = string
}

variable "location" {
  description = "Azure region for networking resources"
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
