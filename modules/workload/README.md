# Workload Module

Creates complete application infrastructure including:

- **GitHub repository creation (optional, enabled by default)**
- Azure AD groups (admins, developers)
- OIDC-enabled service principal for GitHub Actions
- Azure resource group and Key Vault (optional)
- Default storage account per environment (optional)
- RBAC assignments via a built-in default permission catalog

Notes

- Groups are standardized and created automatically
- Admins get a single, platform-level Storage Blob Data Contributor assignment on the app's TF state container (exposed via `platform_permissions` and not duplicated per env)
- Per-group, per-env permissions are available in `application_payload`

Example

```hcl
module "myapp" {
  source = "../../modules/workload"

  app_name     = "myapp"
  display_name = "My App"
  environments = ["prod"]

  admin_users = ["admin@contoso.com"]
  developers  = ["group:platform-engineers"]

  create_key_vault = true

  azure_oidc = {
    enabled    = true
    repository = "contoso-eng/myapp"
    required_resource_access = [
      {
        resource_app_id = "00000003-0000-0000-c000-000000000000" # Graph
        resource_accesses = [{ id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d", type = "Scope" }]
      }
    ]
  }
}
```

## Inputs (selected)

- `app_name` (string): Short name used in resource naming
- `display_name` (string): Human-friendly app name
- `environments` (list(string)): ["prod"], ["prod","test","dev"], or [] for single-env
- `admin_users` (list(string)) — supports users (`user@domain`), service principals (`SPName`), and Entra security groups (`group:GroupName`)
- `developers` (list(string)) — cross-env group; same member formats; gated by `include_developers_group`
- `include_developers_group` (bool)
- `create_resource_group` / `create_key_vault` (bool): create-or-use per environment (`existing_*_ids` maps for the "use" case)
- `azure_oidc` (object): enable, repository, optional API permissions
- `create_github_repo` (bool): Create a GitHub repository for this application (default: true)
- `github_environments` (list(string)): GitHub Environment names to create; each also gets an OIDC federated credential subject (default: [])
- `create_default_storage` (bool): Create default storage account per environment (default: false)
- `storage_account_name_prefix` (string): Optional override for storage account name prefix (max 17 chars)
- `default_storage` (object): Storage configuration with opinionated security defaults
- `state_resource_group_name` / `state_storage_account_name` (string): where the platform keeps Terraform state
- `state_readers_group_object_id` (string): optional shared terraform-state-readers group; the app admin group is added when set

## GitHub Repository

By default, the workload module creates a **private GitHub repository** (with vulnerability alerts enabled) and seeds it with **backend configuration** (`infra/terraform/backend.tf` or `infra/terraform/{env}/backend.tf`) — pre-configured with the correct storage container and state key.

After seeding, Terraform **hands off** — the `backend.tf` files have `lifecycle { ignore_changes = [content] }` so developers can modify them without the platform reverting changes.

### Deployment Environments

Deploy jobs gated on a GitHub Environment present an OIDC subject of `repo:<org>/<repo>:environment:<name>` instead of a branch ref. Opt in with `github_environments` to create the environment **and** the matching federated credential subject from one list, so the two can't drift apart:

```hcl
github_environments = ["prod"]
```

Like the backend files, the environment is create-once-then-hands-off (`ignore_changes = all`): app teams configure reviewers, wait timers, and branch policies in their repo settings without the platform reverting them. Only the environment's existence — what the OIDC claim needs — is guaranteed here.

The `main` branch federated credential is always kept — plan/CI jobs on main outside the gate still authenticate. Pull-request workflows deliberately get **no** federated credential subject: untrusted code gets no cloud identity. The GitHub Environment resource is gated on `create_github_repo` like the other repo resources; for pre-existing repos (`create_github_repo = false`) the federated credential is still created, but the environment itself must be created manually.

> **Append, don't reorder.** Federated credentials in the underlying `app-registration` module are indexed by list position (`count`), and env subjects are appended after `main`. Adding an entry to `github_environments` is safe (existing indices unchanged). **Reordering** the list rewrites the credentials at those positions — Terraform destroys and recreates them, briefly breaking OIDC for any deploy running mid-apply. Add new environments at the end.

### Requirements

The `github` Terraform provider must be configured in the calling stack:

```hcl
github = {
  source  = "integrations/github"
  version = "~> 6.0"
}
```

```hcl
provider "github" {
  owner = var.github_org
}
```

### Authentication

The Terraform GitHub provider authenticates via the `GITHUB_TOKEN` environment variable. Anyone running `terraform plan` or `terraform apply` on app stacks needs this set:

```bash
gh auth login --scopes repo,workflow
export GITHUB_TOKEN=$(gh auth token)
```

**Required scopes:**

- `repo` — create private repositories and push files
- `workflow` — commit workflow files (`.github/workflows/`)

### State Key Naming Convention

State keys use **nested paths** that mirror the directory structure inside the blob container (`{app_name}-tfstate`):

| Directory | State Key | Full blob path |
|-----------|-----------|----------------|
| `infra/terraform/` (root) | `terraform.tfstate` | `myapp-tfstate/terraform.tfstate` |
| `infra/terraform/prod/` | `prod/terraform.tfstate` | `myapp-tfstate/prod/terraform.tfstate` |
| `infra/terraform/prod/network/` | `prod/network/terraform.tfstate` | `myapp-tfstate/prod/network/terraform.tfstate` |

Why nested instead of flat (`prod.terraform.tfstate`): if a developer later splits `prod/` into sub-modules like `prod/network/` and `prod/storage/`, nested keys keep the container organized as a natural tree. Flat keys would create awkward siblings (`prod.terraform.tfstate` next to `prod/network/terraform.tfstate`).

**What Terraform seeds:** The initial root or per-env `backend.tf` files. Everything below that level is owned by the developer.

### Disabling

For existing repos that predate the workload module:

```hcl
create_github_repo = false
```

## Default Permissions

Every application automatically receives these environment-aware permissions:

**Admin Groups:**
- Resource Group: `Owner` (full control)
- Key Vault: `Key Vault Administrator` (full KV access)
- Terraform State: `Storage Blob Data Contributor` (read/write state)

**Developer Groups (environment-aware):**
- Single-environment or Production:
  - Resource Group: `Reader` (view only)
  - Key Vault: `Key Vault Secrets User` (read secrets only)
  - Terraform State: `Storage Blob Data Reader`
- Non-production (test/dev):
  - Resource Group: `Contributor` (manage resources)
  - Key Vault: `Key Vault Secrets Officer` (manage secrets)
  - Terraform State: `Storage Blob Data Reader`

**Terraform State Readers:**
- An optional shared platform group (`state_readers_group_object_id`) that grants `Reader` on the state storage account
- All OIDC service principals are automatically added via the admin group
- Enables backend initialization without granting per-app permissions

## Default Storage Account

Optionally (`create_default_storage = true`), the workload module provisions **one storage account per environment** with production-grade security settings. This handles the common case where every app needs basic blob storage for runtime operations (Function Apps, file uploads, logs, etc.).

### Security Posture (Opinionated Defaults)

- **TLS 1.2 minimum** - No legacy protocols
- **Public network access disabled** - Private by default
- **Shared access keys disabled** - Enforces Managed Identity authentication
- **Trusted Azure services allowed** - Enables Azure-to-Azure communication
- **Blob versioning enabled** - Protects against accidental deletion
- **Soft delete enabled** - 7-day retention for blobs and containers

### What Gets Created

- Storage account name: `{app_name_slug}{env_slug}{location_code}` (e.g., `paymentsprdeus2`)
- Naming logic:
  - App name is auto-slugged: lowercase, special chars removed, truncated to 17 chars
  - Environment slugged to 3 chars: `prod`→`prd`, `dev`→`dev`, `test`→`tst`, etc.
  - Location slugged to 3-4 chars: `eastus2`→`eus2`, `westus`→`wus`, etc.
- Exposed in outputs: name, ID, blob endpoint **only**
- NO access keys or connection strings in outputs (use Managed Identity in app repos)

If your app name is long or you want a specific prefix, use `storage_account_name_prefix` (max 17 chars, lowercase + numbers only).

### In Application Repos

App repos receive storage identifiers via `application_payload.infrastructure.storage_accounts` (through remote state) and grant their own managed identities data-plane roles against those IDs. Apps needing databases, specialized storage, or private endpoints provision that in their own repos — the default account covers basic runtime needs only.

## Outputs

- `application_payload`: app_info, infrastructure (includes storage_accounts), oidc, groups with per-env permissions
- `platform_permissions`: platform-level, cross-env assignments (e.g., admin SBDC on TF state)
- `terraform_backend_config`: ready-to-use backend coordinates for the app's state
- `storage_account_names` / `storage_account_ids`: Map of environment to storage account name/ID
