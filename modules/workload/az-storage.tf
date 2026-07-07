# ============================================================================
# Default Storage Account (one per environment)
# ============================================================================
# Creates a baseline storage account for each environment with opinionated
# security defaults. Apps can provision additional storage in their own repos.
#
# Security posture:
# - TLS 1.2 minimum
# - Public network access disabled by default
# - Shared access keys disabled (prefer Managed Identity)
# - Allow trusted Azure services
# - Blob versioning and soft delete enabled
# ============================================================================

locals {
  # Location code mapping (Azure region -> short code, 3-4 chars)
  location_codes = {
    "eastus"         = "eus"
    "eastus2"        = "eus2"
    "westus"         = "wus"
    "westus2"        = "wus2"
    "westus3"        = "wus3"
    "centralus"      = "cus"
    "northcentralus" = "ncus"
    "southcentralus" = "scus"
  }

  location_code = lookup(local.location_codes, var.location, "eus2")

  # Environment slugs (max 3 chars)
  env_slugs = {
    ""            = "" # Single-env, no suffix
    "prod"        = "prd"
    "production"  = "prd"
    "test"        = "tst"
    "testing"     = "tst"
    "dev"         = "dev"
    "development" = "dev"
    "stage"       = "stg"
    "staging"     = "stg"
    "feat"        = "ftr"
    "feature"     = "ftr"
  }

  # Slugify app name to max 17 chars
  # Option 1: Use explicit storage_account_name_prefix if provided (already validated)
  # Option 2: Auto-slug from app_name (strip special chars, truncate to 17)
  app_name_clean = replace(replace(replace(lower(var.app_name), "-", ""), "_", ""), " ", "")
  app_name_slug  = var.storage_account_name_prefix != "" ? var.storage_account_name_prefix : substr(local.app_name_clean, 0, 17)

  # Generate storage account name: {app_name_slug}{env_slug}{location} (max 24 chars)
  # Format: appname (max 17) + env (max 3) + location (3-4) = max 24 chars
  # Example: payments + prd + eus2 = paymentsprdeus2 (15 chars)
  storage_account_names = var.create_default_storage ? {
    for env in local.environments : env => (
      "${local.app_name_slug}${lookup(local.env_slugs, env, substr(replace(env, "-", ""), 0, 3))}${local.location_code}"
    )
  } : {}

  # Transform simple container list into module format
  storage_containers = [
    for name in var.default_storage.containers : {
      name                  = name
      container_access_type = "private"
    }
  ]
}

module "default_storage" {
  for_each = local.storage_account_names

  source = "../storage/storage_account"

  storage_account_name = each.value
  resource_group       = azurerm_resource_group.app_rg[each.key]
  purpose              = "application_runtime"

  # Basic configuration
  account_tier             = var.default_storage.account_tier
  account_replication_type = var.default_storage.account_replication_type
  account_kind             = var.default_storage.account_kind
  access_tier              = var.default_storage.access_tier

  # Security settings (opinionated defaults)
  min_tls_version                 = var.default_storage.min_tls_version
  allow_nested_items_to_be_public = var.default_storage.allow_nested_items_to_be_public
  public_network_access_enabled   = var.default_storage.public_network_access_enabled
  shared_access_key_enabled       = var.default_storage.shared_access_key_enabled

  # Network rules
  network_rules = var.default_storage.network_rules

  # Blob properties
  blob_properties = var.default_storage.blob_properties

  # Containers (simple plumbing only)
  containers = local.storage_containers

  tags = merge(local.default_tags_template, var.tags, {
    Environment = each.key == "" ? "prod" : each.key
    Component   = "storage"
  })
}
