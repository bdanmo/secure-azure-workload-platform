/*
 * Workload Module Outputs
 */

# Essential metadata for platform and workflows
output "display_name" {
  description = "The application display name"
  value       = var.display_name
}

output "resource_group_names" {
  description = "Names of the application resource groups per environment"
  value       = local.resource_group_names
}

output "resource_group_ids" {
  description = "IDs of the application resource groups per environment"
  value       = local.resource_group_ids
}

output "key_vault_names" {
  description = "Names of the application key vaults per environment"
  value       = local.key_vault_names
}

output "key_vault_ids" {
  description = "IDs of the application key vaults per environment"
  value       = local.key_vault_ids
}

output "terraform_backend_config" {
  description = "Backend coordinates for app-specific Terraform state"
  value = {
    resource_group_name  = "rg-platform-iac"
    storage_account_name = "contosoiaceastus2"
    container_name       = azurerm_storage_container.terraform_state.name
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Groups created with their members
output "groups_created" {
  description = "All groups created with their members"
  value       = local.group_details
}
