# Security model

Threats this design addresses, and how. Also what it deliberately does not cover.

## Credential theft from CI/CD

**Risk:** long-lived client secrets or storage keys in GitHub secrets leak (log exposure, fork PRs, compromised runners) and work from anywhere until rotated.

**Mitigation:** there are no deploy credentials. GitHub Actions authenticates via OIDC federation: the workflow's identity token is exchanged for an Azure token only when the token's subject matches a federated credential on the app registration. Subjects are deliberately narrow — the `main` branch and explicit `environment:<name>` claims. Pull-request workflows get no subject and therefore no cloud identity; CI for untrusted code runs credential-free (fmt/validate/lint only). The module never creates a client secret unless explicitly asked (`create_password`, off by default), and storage accounts have shared keys disabled.

## Non-prod compromise reaching prod

**Risk:** a compromised dev pipeline or developer account modifies production.

**Mitigation:** environment separation is enforced at three layers. Resources are split per environment (separate RGs, key vaults, storage). Human RBAC tightens in prod: developers hold Contributor in dev/test but only Reader and Key Vault Secrets User in prod. Deploy identity for prod requires a workflow running in the `prod` GitHub environment, whose required reviewers make the deploy approval-gated; the reviewer config lives in GitHub, the trust config in Azure, and both are generated from the same `github_environments` list so they cannot drift apart.

## Privilege sprawl

**Risk:** ad-hoc role assignments accumulate; nobody can say who has what.

**Mitigation:** all role assignments are generated from a small default permission catalog in code (`az-rbac.tf`), keyed by group and environment. Admin scope is bounded to the app's own resource groups — blast radius of a compromised app admin account is that app, not the subscription. Group membership, not direct assignment, is the only access path, and the full grant set is visible in `terraform plan` and the `application_payload` output.

## State tampering and exposure

**Risk:** Terraform state contains resource details and is a write-path to infrastructure; broad access invites tampering or exfiltration.

**Mitigation:** state is accessed with Azure AD auth only (no account keys, `shared_access_key_enabled = false`). Each app gets a dedicated container; `Storage Blob Data Contributor` is granted per-container to the app's admin group and CI identity, `Data Reader` to developers. No app can read another app's state.

## VM access

**Risk:** shared SSH keys, unmanaged authorized_keys files, no audit trail of who logged in.

**Mitigation:** `compute/linux_vm` uses Entra ID SSH login. Access is granted through two AD groups per VM — user login (no sudo) and administrator login (sudo) — mapped to the corresponding Azure RBAC data-plane roles. Sign-ins inherit MFA and Conditional Access policies and appear in Entra sign-in logs. VMs get no public IP, and the VM's own managed identity holds no Key Vault access unless a feature (repo cloning, SMB credentials) explicitly requires a scoped secret read.

## Secret storage

**Risk:** secrets in code, state, or pipeline variables.

**Mitigation:** per-environment Key Vaults in RBAC mode with purge protection; access via the same group catalog (Secrets User in prod, Secrets Officer in non-prod). SMB credentials for VM mounts are fetched from Key Vault by the VM's managed identity at boot, not embedded in cloud-init or state.

## Scanner posture

CI runs `terraform validate`, tflint, and checkov on every PR with no cloud credentials. Checkov runs with a documented skip list (`.checkov.yaml`): skips are either demo-scope boundaries (private endpoints, central logging — owned by network/ops layers in a real estate) or checks the tool cannot evaluate through `optional()` object defaults. No check is skipped silently.

## Known gaps

Deliberately out of scope for the workload layer, owned elsewhere in a real deployment:

- Private endpoints and Key Vault/storage network ACLs (network layer)
- Centralized diagnostic settings and log retention (ops layer)
- Azure Policy guardrails and Defender plans (security layer)
- Branch protection on seeded repos (handed off to app teams with the repo)
- Customer-managed keys — platform-managed encryption is accepted here
