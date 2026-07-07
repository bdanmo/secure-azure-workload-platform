# App Registration Module (app-registration)

## Purpose

- Create a Microsoft Entra ID application object + service principal with optional GitHub OIDC and optional client secret in Key Vault
- Or attach OIDC to an existing application (no new app created), optionally ensuring a service principal exists

## Behavior

- **Create mode**: when `existing_app` is null, creates application + service principal
- **Attach mode**: when `existing_app` is provided, uses those IDs and only manages SP/OIDC as requested

## Inputs (selected)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `github_repository` | string|null | null | `org/repo` shorthand; auto-builds app name, display name, description, and default federated credentials |
| `github_branches` | list(string) | `["main"]` | Branches to federate when `github_repository` is set |
| `github_environments` | list(string) | `[]` | GitHub environments to federate (e.g., `["prod", "staging"]`) |
| `github_include_pull_request` | bool | `false` | Include the `pull_request` subject when `github_repository` is set |
| `app_name` | string|null | null | Short name override when you don't want the repo-derived default |
| `display_name` | string|null | null | Human-readable override; defaults to `GitHub OIDC <Repo>` when repo provided |
| `environment` | string|null | null | Appended to display name when provided |
| `owners` | list(string) | `[]` | AAD object IDs to set as owners |
| `required_resource_access` | list | `[]` | API permissions to add |
| `create_password` | bool | `false` | Create a client secret |
| `key_vault_name` | string|null | null | Key Vault name for storing secret |
| `key_vault_resource_group_name` | string|null | null | Key Vault resource group |
| `key_vault_secret_name` | string|null | null | Optional custom secret name |
| `github_oidc` | object|null | null | Explicit federated credential list; bypasses repo-derived defaults |
| `existing_app` | object|null | null | `{ application_object_id, client_id, display_name? }` |
| `create_sp_if_missing` | bool | `true` | Ensure SP exists in attach mode |
| `tags` | map(string) | `{}` | Additional tags |

## Outputs

- `client_id`, `application_object_id`, `service_principal_id`, `display_name`
- `key_vault_secret_id`, `key_vault_secret_name` (when create_password + key vault)
- `configuration`: includes all settings and generated subjects

## Examples

### Production SP with environment-based deployment

```hcl
module "my_service" {
  source              = "../../modules/app-registration"
  github_repository   = "Org/my-service"
  github_environments = ["prod"]  # creates environment:prod subject
  owners              = [data.azurerm_client_config.current.object_id]
}
```

### Read-only SP for PR testing

```hcl
module "my_service_readonly" {
  source                      = "../../modules/app-registration"
  app_name                    = "github-oidc-my-service-pr"
  display_name                = "GitHub OIDC My Service (PR Read-Only)"
  github_repository           = "Org/my-service"
  github_branches             = []    # no branch subjects
  github_include_pull_request = true  # PR access only
  owners                      = [data.azurerm_client_config.current.object_id]
  # Assign read-only permissions here
}
```

### Multiple environments and branches

```hcl
module "my_service_identity" {
  source              = "../../modules/app-registration"
  github_repository   = "Org/my-service"
  github_branches     = ["main", "release"]
  github_environments = ["prod", "staging"]
  owners              = [data.azurerm_client_config.current.object_id]
}
```

### Custom OIDC subjects (advanced)

```hcl
module "my_app" {
  source       = "../../modules/app-registration"
  app_name     = "my-app"
  display_name = "My App"
  environment  = "prod"
  owners       = [data.azurerm_client_config.current.object_id]
  github_oidc  = {
    subjects = [{
      name        = "custom-subject"
      subject     = "repo:Org/repo:ref:refs/heads/main"
      description = "Custom subject"
    }]
  }
}
```

### Attach OIDC to existing app

```hcl
module "existing_app" {
  source = "../../modules/app-registration"
  existing_app = {
    application_object_id = "/applications/00000000-0000-0000-0000-000000000000"
    client_id             = "00000000-0000-0000-0000-000000000000"
    display_name          = "Existing App"
  }
  create_sp_if_missing = true
  github_repository    = "Org/repo"
  github_environments  = ["prod"]
}
```

## Security Notes

- **Separate SPs for different permission levels**: Don't use the same SP for PR testing and production deploys
- **`github_include_pull_request = false` by default**: PR subjects allow anyone who can open a PR to authenticate; enable only for read-only SPs
- **Use `github_environments` for protected deployments**: GitHub environments support approval gates and secrets
