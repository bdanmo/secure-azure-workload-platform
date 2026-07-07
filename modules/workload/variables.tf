variable "app_name" {
  description = "Short name of the application (used in resource naming)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "The app_name must be lowercase alphanumeric with optional hyphens."
  }
}

variable "display_name" {
  description = "Human-readable name of the application"
  type        = string
}

variable "description" {
  description = "Description of the application"
  type        = string
  default     = ""
}

variable "environments" {
  description = "List of environments (e.g., ['prod', 'test']). Empty list [] for single-environment apps."
  type        = list(string)
  default     = ["prod"]
  validation {
    condition     = length(var.environments) == 0 || alltrue([for env in var.environments : contains(["prod", "test", "dev"], env)])
    error_message = "Environments must be empty [] or one of: prod, test, dev."
  }
}

variable "admin_users" {
  description = "List of admin users"
  type        = list(string)
  default     = []
}

variable "developers" {
  description = "List of developer users (cross-environment)"
  type        = list(string)
  default     = []
}

variable "include_developers_group" {
  description = "Whether to create developers groups"
  type        = bool
  default     = true
}

variable "create_resource_group" {
  description = "Create an Azure resource group per environment"
  type        = bool
  default     = true
}

variable "create_key_vault" {
  description = "Create an Azure Key Vault per environment"
  type        = bool
  default     = false
}

variable "existing_resource_group_ids" {
  description = "Map of environment name to existing resource group ID. Used when create_resource_group = false."
  type        = map(string)
  default     = {}
}

variable "existing_key_vault_ids" {
  description = "Map of environment name to existing Key Vault ID. Used when create_key_vault = false."
  type        = map(string)
  default     = {}
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "state_readers_group_object_id" {
  description = "Object ID of the shared terraform-state-readers group. When set, the app's admin group is added so its members can initialize backends."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "azure_oidc" {
  description = "Azure OIDC configuration"
  type = object({
    enabled    = bool
    repository = string
    role_assignments = optional(list(object({
      role  = string
      scope = string
    })), [])
    required_resource_access = optional(list(object({
      resource_app_id   = string
      resource_accesses = list(object({ id = string, type = string }))
    })), [])
  })
  default = { enabled = false, repository = "" }
}

# ============================================================================
# GitHub Configuration
# ============================================================================

variable "create_github_repo" {
  description = "Create a GitHub repository for this application"
  type        = bool
  default     = true
}

variable "github_environments" {
  description = "GitHub Environment names to create on the repository. Each also adds an OIDC federated credential subject (repo:<repository>:environment:<name>) so environment-gated deploy jobs can authenticate. Gate details (reviewers, wait timers) are configured by the app team in their repo."
  type        = list(string)
  default     = []
}

# ============================================================================
# Default Storage Configuration
# ============================================================================

variable "create_default_storage" {
  description = "Create a default storage account per environment for application runtime needs"
  type        = bool
  default     = false
}

variable "storage_account_name_prefix" {
  description = "Optional override for storage account name prefix (max 17 chars, will be appended with env+location). If not provided, uses app_name."
  type        = string
  default     = ""

  validation {
    condition     = var.storage_account_name_prefix == "" || can(regex("^[a-z0-9]{1,17}$", var.storage_account_name_prefix))
    error_message = "Storage account name prefix must be 1-17 characters, lowercase letters and numbers only."
  }
}

variable "default_storage" {
  description = "Configuration for default storage accounts (one per environment)"
  type = object({
    account_tier             = optional(string, "Standard")
    account_replication_type = optional(string, "LRS")
    account_kind             = optional(string, "StorageV2")
    access_tier              = optional(string, "Hot")

    # Security settings (opinionated defaults)
    min_tls_version                 = optional(string, "TLS1_2")
    allow_nested_items_to_be_public = optional(bool, false)
    public_network_access_enabled   = optional(bool, false)
    shared_access_key_enabled       = optional(bool, false) # Prefer Managed Identity

    # Network rules
    network_rules = optional(object({
      default_action             = optional(string, "Deny")
      bypass                     = optional(list(string), ["AzureServices"])
      ip_rules                   = optional(list(string), [])
      virtual_network_subnet_ids = optional(list(string), [])
    }), {})

    # Blob properties with retention
    blob_properties = optional(object({
      versioning_enabled       = optional(bool, true)
      change_feed_enabled      = optional(bool, false)
      last_access_time_enabled = optional(bool, true)

      delete_retention_policy = optional(object({
        days = optional(number, 7)
      }), { days = 7 })

      container_delete_retention_policy = optional(object({
        days = optional(number, 7)
      }), { days = 7 })
    }), {})

    # Simple container list (plumbing only, no app logic)
    containers = optional(list(string), [])
  })
  default = {}
}
