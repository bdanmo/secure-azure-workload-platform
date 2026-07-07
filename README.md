# secure-azure-workload-platform

Terraform modules for provisioning Azure application workloads with security-first defaults. One module call gives an app team their groups, per-environment infrastructure, least-privilege RBAC, a seeded GitHub repository, and a keyless CI/CD trust relationship.

> This is a sanitized portfolio/demo implementation based on platform engineering patterns from my professional experience. It contains no employer code, secrets, proprietary configuration, tenant data, internal names, or production environment details.

## What this demonstrates

- **Keyless auth via GitHub OIDC** — federated credentials instead of client secrets; PR workflows get no cloud identity at all
- **Environment isolation (dev/test/prod)** — separate resource groups, key vaults, storage, and state per environment
- **Least-privilege RBAC** — role assignments generated from a permission catalog; developers get Contributor in dev/test, Reader in prod
- **Approval-gated production deploys** — GitHub environment reviewers and the matching OIDC subject claim generated from the same list, so gate and trust can't drift apart
- **Reusable module design** — app onboarding is a five-line module call, not copy-paste ([examples/dev-test-prod](examples/dev-test-prod))

## Layout

```
modules/workload/              Complete app workload foundation: groups, per-env infra, RBAC, OIDC, repo seeding
modules/identity/              Reusable identity building blocks (groups, app registrations)
modules/compute/linux_vm/      Linux VM with Entra ID SSH login and role-separated access
modules/storage/               Storage account with opinionated security defaults
examples/dev-test-prod/        Example wiring a workload + VM across three environments
docs/                          Architecture and security model
```

## Quick look

```hcl
module "app" {
  source = "./modules/workload"

  app_name     = "payments"
  display_name = "Payments Service"
  environments = ["dev", "test", "prod"]

  admin_users = ["alee@contoso.com"]
  developers  = ["rpatel@contoso.com"]

  create_key_vault = true
  azure_oidc       = { enabled = true, repository = "contoso-eng/payments" }

  github_environments = ["prod"] # prod deploys require the environment gate
}
```

See [docs/architecture.md](docs/architecture.md) for the design and [docs/security-model.md](docs/security-model.md) for the threat model.

## CI

- `ci.yml` runs credential-free on every PR: `terraform fmt`, `validate` (all modules + example), tflint, and checkov (posture documented in `.checkov.yaml`)
- `infracost.yml` posts a monthly cost diff comment on every Terraform PR (the example root baselines at ~$33/month, almost all of it the dev VM)
- `deploy.yml` is the environment-gated apply for the example root; it needs `AZURE_CLIENT_ID`/`AZURE_TENANT_ID`/`AZURE_SUBSCRIPTION_ID` repo variables wired to a real tenant, so it is dispatch-only and will not run out of the box

All names in the example (`contoso.com`, `contoso-eng`, `rg-platform-iac`, `contosoiaceastus2`) are fictional defaults — override them via module variables for your tenant.

## License

MIT
