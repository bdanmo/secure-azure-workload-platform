output "client_id" {
  description = "The application (client) ID"
  value       = local.application_client_id
}

output "application_object_id" {
  description = "The object ID of the AzureAD application"
  value       = local.application_object_id
}

output "service_principal_id" {
  description = "Object ID of the created or existing service principal (if ensured)"
  value       = try(azuread_service_principal.sp[0].id, null)
}

output "display_name" {
  description = "Display name used for the application"
  value       = local.full_display
}

output "key_vault_secret_id" {
  description = "The ID of the key vault secret containing the client secret (if created)"
  value       = (var.create_password && var.key_vault_name != null) ? azurerm_key_vault_secret.kv_secret[0].id : null
}

output "key_vault_secret_name" {
  description = "The name of the key vault secret containing the client secret (if created)"
  value       = (var.create_password && var.key_vault_name != null) ? azurerm_key_vault_secret.kv_secret[0].name : null
}

output "configuration" {
  description = "Non-sensitive configuration metadata for outputs"
  value = {
    create_password             = var.create_password
    key_vault_name              = var.key_vault_name
    key_vault_secret_name       = var.key_vault_secret_name
    github_oidc                 = local.resolved_github_oidc
    github_repository           = var.github_repository
    github_branches             = var.github_branches
    github_include_pull_request = var.github_include_pull_request
    generated_github_subjects   = local.github_subjects
    environment                 = var.environment
  }
}
