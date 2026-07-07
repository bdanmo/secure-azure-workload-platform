# Architecture

## What this is

A platform layer that provisions the complete foundation an application team needs to operate on Azure: identity, access, infrastructure scaffolding, state storage, and a CI/CD trust relationship — from one module call. App teams then build inside those boundaries from their own repositories.

## The workload module

`modules/workload` composes the smaller building blocks into a turnkey onboarding unit. One call produces:

```
groups        payments-admins, payments-developers (Entra ID, members resolved
              from UPNs, SP display names, or group: references)
infra         rg-payments-{env}-tf resource groups, kv-payments-{env}-tf key
              vaults (RBAC mode, purge protection), one per environment
storage       {app}{env}{region} storage account per environment with secure
              defaults (TLS 1.2+, no shared keys, no public access)
rbac          role assignments generated from a default permission catalog,
              differentiated by environment (see security-model.md)
oidc          app registration + service principal with federated credentials
              for GitHub Actions — no client secrets
repo          a private GitHub repository seeded with working backend config
              pointing at a dedicated state container
```

The sub-modules (`identity/groups`, `identity/app-registration`, `storage/storage_account`, `compute/linux_vm`) are usable on their own; the workload module is the opinionated composition.

## Execution model

Two distinct planes with different trust levels:

- **Platform plane (this repo)** is applied by platform administrators with Azure CLI auth. Changes here move security boundaries — groups, role assignments, federated credentials — so they get human review and human execution. There is no long-lived, highly-privileged automation identity.
- **Application plane (seeded repos)** deploys through GitHub Actions using the OIDC service principal created here. Application pipelines operate inside the boundary: their identity can only reach their own resource groups, key vaults, and state container.

## State topology

All state lives in a platform storage account under Azure AD authentication (`use_azuread_auth = true`, shared keys disabled). Each workload gets its own blob container (`{app}-tfstate`), and seeded backend keys mirror the app repo's directory tree (`prod/terraform.tfstate`, `prod/network/terraform.tfstate`) so state stays organized as apps split their roots.

Humans read state; only CI/CD identities write it. Admin groups get `Storage Blob Data Contributor` scoped to their app's container only.

## Environment isolation

Environments (`dev`, `test`, `prod`) each get their own resource group, key vault, and storage account, with RBAC that loosens in non-prod (developers get Contributor) and tightens in prod (Reader). The `github_environments` list drives both the GitHub environment resource and the matching OIDC federated credential subject (`repo:<org>/<repo>:environment:<name>`) from one place, so the deploy gate and the cloud trust can't drift apart. Production's GitHub environment carries required reviewers, making prod deploys approval-gated end to end.

## In a real estate

This repo shows the workload layer. In a full deployment it sits alongside per-domain stacks — network (VNets, DNS), identity (shared groups like terraform-state-readers), security (policy, Defender) — each with its own state, consumed here via data sources or variables (e.g. `state_readers_group_object_id`). The `linux_vm` module similarly assumes shared network and auth key vault infrastructure owned by those stacks.
