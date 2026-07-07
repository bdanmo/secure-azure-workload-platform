terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Handle flexible resource group input (object or string)
locals {
  resource_group_name     = try(var.resource_group.name, var.resource_group)
  resource_group_location = try(var.resource_group.location, null)

  # Default tags
  default_tags = {
    "ManagedBy" = "Terraform"
    "Purpose"   = var.purpose
  }

  # Merge default tags with provided tags
  final_tags = merge(local.default_tags, var.tags)
}

# Data source for existing resource group (only when needed)
data "azurerm_resource_group" "main" {
  count = try(var.resource_group.name, null) == null ? 1 : 0
  name  = local.resource_group_name
}

# Storage account
resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location != null ? local.resource_group_location : (length(data.azurerm_resource_group.main) > 0 ? data.azurerm_resource_group.main[0].location : var.location)

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = var.account_kind
  access_tier              = var.access_tier

  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  shared_access_key_enabled       = var.shared_access_key_enabled
  public_network_access_enabled   = var.public_network_access_enabled

  # Network rules
  dynamic "network_rules" {
    for_each = var.public_network_access_enabled && length(var.network_rules.ip_rules) > 0 || length(var.network_rules.virtual_network_subnet_ids) > 0 ? [1] : []
    content {
      default_action             = var.network_rules.default_action
      bypass                     = var.network_rules.bypass
      ip_rules                   = var.network_rules.ip_rules
      virtual_network_subnet_ids = var.network_rules.virtual_network_subnet_ids
    }
  }

  # Blob properties
  dynamic "blob_properties" {
    for_each = var.account_kind == "StorageV2" || var.account_kind == "BlobStorage" ? [1] : []
    content {
      versioning_enabled       = var.blob_properties.versioning_enabled
      change_feed_enabled      = var.blob_properties.change_feed_enabled
      default_service_version  = var.blob_properties.default_service_version
      last_access_time_enabled = var.blob_properties.last_access_time_enabled

      # CORS rules
      dynamic "cors_rule" {
        for_each = var.blob_properties.cors_rule
        content {
          allowed_headers    = cors_rule.value.allowed_headers
          allowed_methods    = cors_rule.value.allowed_methods
          allowed_origins    = cors_rule.value.allowed_origins
          exposed_headers    = cors_rule.value.exposed_headers
          max_age_in_seconds = cors_rule.value.max_age_in_seconds
        }
      }

      # Delete retention policy
      dynamic "delete_retention_policy" {
        for_each = var.blob_properties.delete_retention_policy != null ? [var.blob_properties.delete_retention_policy] : []
        content {
          days = delete_retention_policy.value.days
        }
      }

      # Container delete retention policy
      dynamic "container_delete_retention_policy" {
        for_each = var.blob_properties.container_delete_retention_policy != null ? [var.blob_properties.container_delete_retention_policy] : []
        content {
          days = container_delete_retention_policy.value.days
        }
      }
    }
  }

  tags = local.final_tags
}

# Create containers
resource "azurerm_storage_container" "containers" {
  for_each = {
    for container in var.containers : container.name => container
  }

  name                  = each.value.name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = each.value.container_access_type
}