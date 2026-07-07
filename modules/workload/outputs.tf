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

output "platform_permissions" {
  description = "Global (cross-env) role assignments for this application"
  value = contains(keys(local.groups), "admins") ? {
    terraform_state = {
      scope_id       = local.scope_mappings["terraform_state_container"]
      container_name = azurerm_storage_container.terraform_state.name
      assignments = {
        admins = ["Storage Blob Data Contributor"]
      }
    }
  } : {}
}

# OIDC service principal (if enabled)
output "oidc_service_principal_id" {
  description = "Object ID of the OIDC service principal"
  value       = var.azure_oidc.enabled ? module.oidc_app_registration[0].service_principal_id : null
}

output "oidc_service_principal_name" {
  description = "Display name of the OIDC service principal"
  value       = var.azure_oidc.enabled ? module.oidc_app_registration[0].display_name : null
}

output "oidc_details" {
  description = "Complete OIDC details for GitHub Actions setup"
  value = var.azure_oidc.enabled ? {
    client_id              = module.oidc_app_registration[0].client_id
    tenant_id              = data.azurerm_client_config.current.tenant_id
    subscription_id        = data.azurerm_client_config.current.subscription_id
    service_principal_id   = module.oidc_app_registration[0].service_principal_id
    service_principal_name = module.oidc_app_registration[0].display_name
    group_memberships = [
      "${var.app_name}-admins",
      "terraform-state-readers"
    ]
  } : null
}

output "repository_url" {
  description = "GitHub repository URL used for OIDC integration"
  value       = var.azure_oidc.repository
}

output "oidc_enabled" {
  description = "Whether Azure OIDC is enabled for this application"
  value       = var.azure_oidc.enabled
}
