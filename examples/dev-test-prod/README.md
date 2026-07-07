# Example: dev/test/prod workload

Provisions a complete `payments` application foundation across three environments, plus a utility VM in dev.

What one module call gets the app team:

- Azure AD groups: `payments-admins`, `payments-developers` (members resolved from UPNs, object IDs, service principal display names, or `group:` references)
- Per-environment resource groups and Key Vaults: `rg-payments-{env}-tf`, `kv-payments-{env}-tf`
- Per-environment storage accounts with security defaults (TLS 1.2+, no public access, no shared keys)
- Environment-differentiated RBAC: developers get Contributor in dev/test but Reader in prod
- A GitHub repository seeded with backend config pointing at a dedicated state container
- A GitHub OIDC service principal — keyless deploys from Actions, no client secrets anywhere
- A `prod` GitHub environment wired to a matching OIDC federated credential subject, so production deploys can be approval-gated

## Prerequisites

- Azure CLI login with permissions to create AD groups, app registrations, resource groups, and role assignments
- A GitHub token (or GitHub App) with org repo-creation rights for the `github` provider
- The shared network/auth infrastructure referenced by the VM module defaults (or override those variables)
- The example user UPNs and groups must exist in your tenant — replace `*@contoso.com` with real users

## Run

```bash
cp terraform.tfvars.example terraform.tfvars   # adjust values
terraform init
terraform plan
```
