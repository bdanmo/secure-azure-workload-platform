# secure-azure-workload-platform

Terraform modules for provisioning Azure application workloads with security-first defaults: keyless GitHub Actions authentication via OIDC, environment isolation, least-privilege RBAC, and approval-gated production deploys.

> This is a sanitized portfolio/demo implementation based on platform engineering patterns from my professional experience. It contains no employer code, secrets, proprietary configuration, tenant data, internal names, or production environment details.

## Layout

```
modules/workload/              Complete app workload foundation: groups, per-env infra, RBAC, GitHub OIDC
modules/identity/              Reusable identity building blocks (groups, app registrations)
modules/compute/linux_vm/      Linux VM with Entra ID SSH login and role-separated access
modules/storage/               Storage account with opinionated security defaults
examples/dev-test-prod/        Example wiring a workload across three environments
docs/                          Architecture and security model
```

## Status

Under construction — modules land incrementally.
