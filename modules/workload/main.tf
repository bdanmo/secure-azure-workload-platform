/*
 * Workload Module
 *
 * Creates complete application infrastructure including:
 * - Azure AD groups (admins, developers)
 * - Azure OIDC service principal with GitHub federation
 * - Azure resource group and key vault (optional)
 * - RBAC role assignments via a permission catalog
 */

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

locals {
  # Simple environment handling: empty list = single environment with no suffix
  environments = length(var.environments) == 0 ? [""] : var.environments

  # Build resource names per environment
  environment_resources = {
    for env in local.environments : env => {
      resource_group_name = env == "" ? "rg-${var.app_name}-tf" : "rg-${var.app_name}-${env}-tf"
      key_vault_name      = env == "" ? "kv-${var.app_name}-tf" : "kv-${var.app_name}-${env}-tf"
    }
  }

  # Build display name
  full_display_name = var.description != "" ? var.description : var.display_name

  # Default tags template (will be merged with environment-specific tags)
  default_tags_template = {
    ManagedBy   = "Terraform"
    Application = var.app_name
  }
}
