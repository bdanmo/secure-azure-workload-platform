output "storage_account" {
  description = "The storage account object"
  value       = azurerm_storage_account.main
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "primary_location" {
  description = "Primary location of the storage account"
  value       = azurerm_storage_account.main.primary_location
}

output "secondary_location" {
  description = "Secondary location of the storage account"
  value       = azurerm_storage_account.main.secondary_location
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_queue_endpoint" {
  description = "Primary queue endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_queue_endpoint
}

output "primary_table_endpoint" {
  description = "Primary table endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_table_endpoint
}

output "primary_file_endpoint" {
  description = "Primary file endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_file_endpoint
}

output "primary_access_key" {
  description = "Primary access key of the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "secondary_access_key" {
  description = "Secondary access key of the storage account"
  value       = azurerm_storage_account.main.secondary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "Primary connection string of the storage account"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "secondary_connection_string" {
  description = "Secondary connection string of the storage account"
  value       = azurerm_storage_account.main.secondary_connection_string
  sensitive   = true
}

output "containers" {
  description = "Map of created containers"
  value       = azurerm_storage_container.containers
}

output "resource_group_name" {
  description = "Name of the resource group containing the storage account"
  value       = local.resource_group_name
}

output "tags" {
  description = "Tags applied to the storage account"
  value       = azurerm_storage_account.main.tags
}