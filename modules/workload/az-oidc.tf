# Create Azure OIDC service principal and wire it to groups
module "oidc_app_registration" {
  count  = var.azure_oidc.enabled ? 1 : 0
  source = "../identity/app-registration"

  app_name     = "github-oidc-${var.app_name}"
  display_name = "GitHub OIDC ${var.display_name}"
  description  = "OIDC federated identity for ${var.azure_oidc.repository} GitHub Actions"

  # Set current user as owner
  owners = [
    data.azurerm_client_config.current.object_id
  ]

  # API permissions
  required_resource_access = var.azure_oidc.required_resource_access

  # GitHub OIDC federated credentials.
  # Deliberately narrow: main branch plus explicit environment subjects only.
  # No pull_request subject — workflows triggered by PRs get no cloud identity.
  github_oidc = {
    subjects = concat([
      {
        name        = "${var.app_name}-main-branch"
        subject     = "repo:${var.azure_oidc.repository}:ref:refs/heads/main"
        description = "Main branch workflows"
      }
      ], [
      for env in var.github_environments : {
        name        = "${var.app_name}-environment-${env}"
        subject     = "repo:${var.azure_oidc.repository}:environment:${env}"
        description = "Environment ${env} deployment workflows"
      }
    ])
  }

  create_password = false
  tags            = merge(local.default_tags_template, var.tags, { AuthType = "GitHub-OIDC" })
}

# Add OIDC SP to application admin group
resource "azuread_group_member" "oidc_sp_admin" {
  count            = var.azure_oidc.enabled ? 1 : 0
  group_object_id  = local.groups["admins"]
  member_object_id = module.oidc_app_registration[0].service_principal_id
}
