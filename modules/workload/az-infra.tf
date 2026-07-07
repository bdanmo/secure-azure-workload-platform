# Create or reference Azure infrastructure per environment

# Create resource groups per environment if requested
resource "azurerm_resource_group" "app_rg" {
  for_each = var.create_resource_group ? toset(local.environments) : toset([])

  name     = local.environment_resources[each.key].resource_group_name
  location = var.location
  tags     = merge(local.default_tags_template, var.tags, { Environment = each.key == "" ? "prod" : each.key })
}

# Get the resource groups
locals {
  resource_group_ids = merge(
    { for k, v in azurerm_resource_group.app_rg : k => v.id },
    var.existing_resource_group_ids
  )
  resource_group_names = merge(
    { for k, v in azurerm_resource_group.app_rg : k => v.name },
    { for k, v in var.existing_resource_group_ids : k => element(split("/", v), length(split("/", v)) - 1) }
  )
}

# Create key vaults per environment if requested
resource "azurerm_key_vault" "app_kv" {
  for_each = var.create_key_vault ? toset(local.environments) : toset([])

  name                      = local.environment_resources[each.key].key_vault_name
  location                  = var.location
  resource_group_name       = local.environment_resources[each.key].resource_group_name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true

  tags = merge(local.default_tags_template, var.tags, { Environment = each.key == "" ? "prod" : each.key })

  depends_on = [
    azurerm_resource_group.app_rg,
  ]
}

# Get the key vaults
locals {
  key_vault_ids = merge(
    { for k, v in azurerm_key_vault.app_kv : k => v.id },
    var.existing_key_vault_ids
  )
  key_vault_names = merge(
    { for k, v in azurerm_key_vault.app_kv : k => v.name },
    { for k, v in var.existing_key_vault_ids : k => element(split("/", v), length(split("/", v)) - 1) }
  )
}

# Create dedicated Terraform state container for this application
resource "azurerm_storage_container" "terraform_state" {
  name                  = "${var.app_name}-tfstate"
  storage_account_name  = "contosoiaceastus2" # TODO: make this dynamic with a variable later, please
  container_access_type = "private"
}

# Current client config for tenant/subscription info
data "azurerm_client_config" "current" {}
