output "resource_group_name" {
  description = "Name of the state storage resource group"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Name of the state storage account"
  value       = azurerm_storage_account.state.name
}

output "storage_container_name" {
  description = "Name of the tfstate container"
  value       = azurerm_storage_container.tfstate.name
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.state.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.state.id
}

output "private_endpoint_subnet_id" {
  description = "ID of the private endpoint subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "private_endpoint_ip" {
  description = "Private IP address of the storage account"
  value       = azurerm_private_endpoint.state_storage.private_service_connection[0].private_ip_address
}

output "backend_config" {
  description = "Backend configuration for main Terraform"
  value = <<-EOT
    terraform {
      backend "azurerm" {
        resource_group_name  = "${azurerm_resource_group.state.name}"
        storage_account_name = "${azurerm_storage_account.state.name}"
        container_name       = "${azurerm_storage_container.tfstate.name}"
        key                  = "dataapi/terraform.tfstate"
      }
    }
  EOT
}
