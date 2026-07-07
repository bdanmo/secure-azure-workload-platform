module "app" {
  source = "../../modules/workload"

  app_name     = "payments"
  display_name = "Payments Service"
  description  = ""
  environments = ["dev", "test", "prod"]

  admin_users = ["alee@contoso.com"]
  developers  = ["rpatel@contoso.com", "group:platform-engineers"]

  # Infrastructure
  create_github_repo     = true
  create_key_vault       = true
  create_default_storage = true

  default_storage = {
    containers = ["ledger-exports"]
  }

  azure_oidc = {
    enabled    = true
    repository = "${var.github_org}/payments"
  }

  # Prod deploys require the GitHub environment gate (reviewers configured in repo)
  github_environments = ["prod"]
}
