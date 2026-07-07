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

variable "admins" {
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
