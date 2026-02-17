output "automation_reader_assignment_id" {
  description = "Resource ID of the Reader role assignment"
  value       = azurerm_role_assignment.automation_reader.id
}

output "automation_storage_blob_contributor_assignment_id" {
  description = "Resource ID of the Storage Blob Data Contributor role assignment"
  value       = azurerm_role_assignment.automation_storage_blob_contributor.id
}
