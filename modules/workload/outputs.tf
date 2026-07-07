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
    resource_group_name  = var.state_resource_group_name
    storage_account_name = var.state_storage_account_name
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

output "storage_account_names" {
  description = "Names of the default storage accounts per environment"
  value = var.create_default_storage ? {
    for env, storage in module.default_storage : env => storage.storage_account_name
  } : {}
}

output "storage_account_ids" {
  description = "IDs of the default storage accounts per environment"
  value = var.create_default_storage ? {
    for env, storage in module.default_storage : env => storage.storage_account_id
  } : {}
}

output "application_payload" {
  description = "Normalized application data: app_info, infrastructure, oidc, groups with permissions"
  value = {
    app_info = {
      display_name    = var.display_name
      subscription_id = data.azurerm_client_config.current.subscription_id
      repository_url  = var.azure_oidc.repository
      environments    = var.environments
    }
    infrastructure = merge(
      {
        resource_group_names = { for k, v in local.resource_group_names : (k == "" ? "default" : k) => v }
        key_vault_names      = { for k, v in local.key_vault_names : (k == "" ? "default" : k) => v }
        terraform_backend_config = {
          resource_group_name  = var.state_resource_group_name
          storage_account_name = var.state_storage_account_name
          container_name       = azurerm_storage_container.terraform_state.name
          key                  = "terraform.tfstate"
          use_azuread_auth     = true
        }
      },
      var.create_default_storage ? {
        storage_accounts = {
          for env, storage in module.default_storage : env => {
            name                  = storage.storage_account_name
            id                    = storage.storage_account_id
            primary_blob_endpoint = storage.primary_blob_endpoint
            # NO access keys or connection strings here - app repos must use Managed Identity
          }
        }
      } : {}
    )
    oidc = var.azure_oidc.enabled ? {
      client_id              = module.oidc_app_registration[0].client_id
      tenant_id              = data.azurerm_client_config.current.tenant_id
      service_principal_id   = module.oidc_app_registration[0].service_principal_id
      service_principal_name = module.oidc_app_registration[0].display_name
      group_memberships = [
        "${var.app_name}-admins",
        "terraform-state-readers"
      ]
    } : null
    groups = {
      for group_name, group_data in local.group_details : group_name => merge(
        group_data,
        {
          permissions = {
            for env_name, env_perms in {
              for env in local.environments : (env == "" ? "prod" : env) => {
                admins     = [for a in local.default_permission_assignments : a.role if a.group_type == "admin" && a.environment == env]
                developers = [for a in local.default_permission_assignments : a.role if a.group_type == "developer" && a.environment == env]
              }
            } :
            env_name => (
              strcontains(group_name, "-admins") ? env_perms.admins :
              strcontains(group_name, "-developers") ? env_perms.developers :
              []
            )
            if length(
              strcontains(group_name, "-admins") ? env_perms.admins :
              strcontains(group_name, "-developers") ? env_perms.developers :
              []
            ) > 0
          }
        }
      )
    }
  }
}
