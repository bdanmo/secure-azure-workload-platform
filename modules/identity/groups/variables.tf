/*
 * Variables for Universal Groups Module
 */

variable "app_name" {
  description = "Prefix for all group names (e.g., 'payments', 'billing')"
  type        = string
}

variable "display_name" {
  description = "Human-readable display name for the application/service (e.g., 'Payments Service', 'Billing Service')"
  type        = string
}

variable "environments" {
  description = "List of environments to create groups for. Empty list means no environment prefix."
  type        = list(string)
  default     = []
}

variable "roles" {
  description = "Map of role names to lists of members (users or service principals). Used for dynamic group generation."
  type        = map(list(string))
  default     = null
}

