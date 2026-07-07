// No explicit mode; behavior is inferred based on whether existing_app is provided.

variable "app_name" {
  type        = string
  description = "Short name of the application (for tags, naming; required for create)"
  default     = null
}

variable "display_name" {
  type        = string
  description = "Human-readable display name (required for create; optional in existing mode)"
  default     = null
}

variable "environment" {
  type        = string
  description = "Optional environment label (prod/test/dev). If null/empty, not appended."
  default     = null
}

variable "description" {
  type        = string
  description = "Description for the application"
  default     = ""
}

variable "owners" {
  type        = list(string)
  description = "Object IDs of owners for the app (used on create only)"
  default     = []
}

variable "required_resource_access" {
  type = list(object({
    resource_app_id   = string
    resource_accesses = list(object({ id = string, type = string }))
  }))
  description = "API permissions to assign to the application (create mode only)"
  default     = []
}

variable "create_password" {
  type        = bool
  description = "Whether to create an application password (create mode only)"
  default     = false
}

variable "key_vault_name" {
  type        = string
  default     = null
  description = "Key Vault name for storing client secret (if create_password)"
}

variable "key_vault_resource_group_name" {
  type        = string
  default     = null
  description = "Key Vault resource group name"
}

variable "key_vault_secret_name" {
  type        = string
  default     = null
  description = "Optional custom secret name"
}

variable "github_oidc" {
  type = object({
    subjects = list(object({
      name        = string
      description = string
      subject     = string
    }))
  })
  description = "GitHub OIDC configuration"
  default     = null
}

variable "github_repository" {
  type        = string
  description = "GitHub repository in the form org/repo; enables automatic app naming and federated credentials"
  default     = null
  validation {
    condition     = var.github_repository == null || can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in the form org/repo."
  }
}

variable "github_branches" {
  type        = list(string)
  description = "Additional GitHub branches (refs/heads) that should receive federated credentials when github_repository is set"
  default     = ["main"]
}

variable "github_include_pull_request" {
  type        = bool
  description = "Whether to include the standard pull_request federated credential when github_repository is set"
  default     = false
}

variable "github_environments" {
  type        = list(string)
  description = "GitHub environments to create federated credentials for (e.g., ['prod', 'staging'])"
  default     = []
}

variable "existing_app" {
  type = object({
    application_object_id = string
    client_id             = string
    display_name          = optional(string)
  })
  description = "Existing application identifiers (required in existing mode)"
  default     = null
}

variable "create_sp_if_missing" {
  type        = bool
  description = "Ensure a service principal exists for the application (existing mode)"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags"
  default     = {}
}
