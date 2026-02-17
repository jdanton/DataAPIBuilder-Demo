output "public_ip_id" {
  description = "Resource ID of the Public IP"
  value       = azurerm_public_ip.main.id
}

output "public_ip_address" {
  description = "The IP address value"
  value       = azurerm_public_ip.main.ip_address
}

output "waf_policy_id" {
  description = "Resource ID of the WAF Policy"
  value       = azurerm_web_application_firewall_policy.main.id
}

output "waf_policy_name" {
  description = "Name of the WAF Policy"
  value       = azurerm_web_application_firewall_policy.main.name
}
