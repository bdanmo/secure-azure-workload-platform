/*
 * Permission Management System
 * Centralized permission catalog and assignment engine.
 */

locals {

  scope_mappings = merge(
    length(local.resource_group_ids) > 0 ? { for env in local.environments : (env == "" ? "resource_group" : "resource_group_${env}") => local.resource_group_ids[env] } : {},
    length(local.key_vault_ids) > 0 ? { for env in local.environments : (env == "" ? "key_vault" : "key_vault_${env}") => local.key_vault_ids[env] } : {},
    {
      subscription              = "/subscriptions/${data.azurerm_client_config.current.subscription_id}",
      terraform_state_container = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.state_resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.state_storage_account_name}/blobServices/default/containers/${azurerm_storage_container.terraform_state.name}"
    }
  )

  default_permissions = {
    admin_groups = {
      for env in local.environments : env => {
        resource_group = ["Owner"]
        key_vault      = ["Key Vault Administrator"]
      }
    }
    developer_groups = {
      for env in local.environments : env => {
        resource_group = (env == "" || env == "prod") ? ["Reader"] : ["Contributor"]
        key_vault      = (env == "" || env == "prod") ? ["Key Vault Secrets User"] : ["Key Vault Secrets Officer"]
      }
    }
  }

  default_permission_assignments = merge(
    {
      for assignment in flatten([
        for env in local.environments : [
          for category, roles in local.default_permissions.admin_groups[env] : [
            for role in roles : [
              for group_name, group_id in local.groups : {
                key         = "${group_name}-${role}-${category}-${env}"
                group_id    = group_id
                role        = role
                scope       = env == "" ? category : "${category}_${env}"
                group_type  = "admin"
                environment = env
              } if can(regex("admins$", group_name))
            ]
          ]
        ]
      ]) : assignment.key => assignment
    },
    {
      for assignment in flatten([
        for env in local.environments : [
          for category, roles in local.default_permissions.developer_groups[env] : [
            for role in roles : [
              for group_name, group_id in local.groups : {
                key         = "${group_name}-${role}-${category}-${env}"
                group_id    = group_id
                role        = role
                scope       = env == "" ? category : "${category}_${env}"
                group_type  = "developer"
                environment = env
              } if can(regex("developers$", group_name))
            ]
          ]
        ]
      ]) : assignment.key => assignment
    }
  )
}

resource "azurerm_role_assignment" "group_permissions" {
  # Only create assignments whose scope actually exists (e.g., skip key_vault when create_key_vault = false)
  for_each = {
    for k, v in local.default_permission_assignments : k => v
    if contains(keys(local.scope_mappings), v.scope)
  }

  scope                = local.scope_mappings[each.value.scope]
  role_definition_name = each.value.role
  principal_id         = each.value.group_id
}

resource "azurerm_role_assignment" "admin_storage" {
  count                = contains(keys(local.groups), "admins") ? 1 : 0
  scope                = local.scope_mappings["terraform_state_container"]
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.groups["admins"]
}

resource "azurerm_role_assignment" "developer_state_read" {
  count                = contains(keys(local.groups), "developers") ? 1 : 0
  scope                = local.scope_mappings["terraform_state_container"]
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = local.groups["developers"]
}
