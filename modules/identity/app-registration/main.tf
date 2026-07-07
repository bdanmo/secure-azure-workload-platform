terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

locals {
  is_create = var.existing_app == null
  is_exist  = !local.is_create

  repo_parts = var.github_repository != null ? split("/", var.github_repository) : null
  repo_name  = local.repo_parts != null && length(local.repo_parts) == 2 ? local.repo_parts[1] : null
  repo_slug  = local.repo_name != null ? replace(replace(lower(local.repo_name), "_", "-"), ".", "-") : null

  default_app_name = var.github_repository != null ? "github-oidc-${local.repo_slug}" : null
  repo_name_human_parts = local.repo_name != null ? [
    for part in split("-", local.repo_name) :
    (length(part) <= 3 ? upper(part) : title(part))
  ] : []
  default_display_name  = var.github_repository != null ? "GitHub OIDC ${trimspace(join(" ", local.repo_name_human_parts))}" : null
  default_description   = var.github_repository != null ? "OIDC federated identity for ${var.github_repository} GitHub Actions" : null
  resolved_app_name     = coalesce(var.app_name, local.default_app_name, "app")
  resolved_display_name = coalesce(var.display_name, local.default_display_name, "App Registration")
  resolved_description  = var.description != "" ? var.description : coalesce(local.default_description, "")

  default_branch_subjects = var.github_repository != null ? [
    for branch in var.github_branches : {
      name        = "${local.repo_slug}-${branch}-branch"
      subject     = "repo:${var.github_repository}:ref:refs/heads/${branch}"
      description = "${title(replace(branch, "-", " "))} branch workflows"
    }
  ] : []
  default_pr_subjects = var.github_repository != null && var.github_include_pull_request ? [{
    name        = "${local.repo_slug}-pull-requests"
    subject     = "repo:${var.github_repository}:pull_request"
    description = "Pull request workflows"
  }] : []
  default_env_subjects = var.github_repository != null ? [
    for env in var.github_environments : {
      name        = "${local.repo_slug}-env-${env}"
      subject     = "repo:${var.github_repository}:environment:${env}"
      description = "${title(env)} environment deployments"
    }
  ] : []
  default_github_subjects = concat(local.default_branch_subjects, local.default_pr_subjects, local.default_env_subjects)
  github_subjects         = var.github_oidc != null ? var.github_oidc.subjects : local.default_github_subjects
  resolved_github_oidc    = var.github_oidc != null ? var.github_oidc : (length(local.github_subjects) > 0 ? { subjects = local.github_subjects } : null)

  base_display = local.is_create ? local.resolved_display_name : coalesce(try(var.existing_app.display_name, null), local.resolved_display_name)
  full_display = (var.environment != null && var.environment != "") ? "${local.base_display} (${title(var.environment)})" : local.base_display

  default_tags = {
    ManagedBy   = "Terraform"
    Application = local.resolved_app_name
  }
  all_tags = (var.environment != null && var.environment != "") ? merge(local.default_tags, { Environment = var.environment }, var.tags) : merge(local.default_tags, var.tags)
  azuread_tags = concat(
    values(local.default_tags),
    (var.environment != null && var.environment != "") ? [var.environment] : [],
    values(var.tags)
  )
}

# Create application if requested
resource "azuread_application" "app" {
  count            = local.is_create ? 1 : 0
  display_name     = local.full_display
  description      = local.resolved_description
  owners           = var.owners
  sign_in_audience = "AzureADMyOrg"
  tags             = local.azuread_tags

  dynamic "required_resource_access" {
    for_each = var.required_resource_access
    content {
      resource_app_id = required_resource_access.value.resource_app_id
      dynamic "resource_access" {
        for_each = required_resource_access.value.resource_accesses
        content {
          id   = resource_access.value.id
          type = resource_access.value.type
        }
      }
    }
  }
}

# Choose application identifiers depending on mode
locals {
  application_object_id = local.is_create ? azuread_application.app[0].id : var.existing_app.application_object_id
  application_client_id = local.is_create ? azuread_application.app[0].client_id : var.existing_app.client_id
}

# Ensure service principal exists
resource "azuread_service_principal" "sp" {
  count     = local.is_create || var.create_sp_if_missing ? 1 : 0
  client_id = local.application_client_id
  owners    = var.owners
  tags      = local.azuread_tags
}

# Optional client secret on create
resource "azuread_application_password" "password" {
  count          = local.is_create && var.create_password ? 1 : 0
  application_id = local.application_object_id
  display_name   = "terraform-managed"
}

# Optional KV secret for the password
data "azurerm_key_vault" "kv" {
  count               = local.is_create && var.create_password && var.key_vault_name != null ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

resource "azurerm_key_vault_secret" "kv_secret" {
  count        = local.is_create && var.create_password && var.key_vault_name != null ? 1 : 0
  name         = coalesce(var.key_vault_secret_name, "sp-${local.resolved_app_name}-client-secret")
  value        = azuread_application_password.password[0].value
  key_vault_id = data.azurerm_key_vault.kv[0].id
  tags         = local.all_tags
}

# Add GitHub OIDC federated identity credentials
resource "azuread_application_federated_identity_credential" "github" {
  count          = length(local.github_subjects)
  application_id = local.application_object_id
  display_name   = local.github_subjects[count.index].name
  description    = local.github_subjects[count.index].description
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = local.github_subjects[count.index].subject
}
