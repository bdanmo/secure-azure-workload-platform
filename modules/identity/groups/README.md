# Universal Groups Module

This module creates Azure AD security groups with flexible configuration options.

## Features

- **Dynamic Mode**: Auto-generate groups using prefix + roles + environments
- **Member Management**: Supports users (UPNs), service principals (display names), and nested groups (`group:` prefix)
- **Environment Support**: Optional environment prefixes for multi-environment setups

## Usage Examples

### Environment-Scoped Groups

```hcl
module "app_groups" {
  source = "../modules/identity/groups"

  app_name = "payments"
  display_name = "Payments Service"
  environments = ["prod"]

  roles = {
    admins = ["github-terraform-deployer"]
    contributors = [
      "alee@contoso.com",
      "rpatel@contoso.com"
    ]
  }
}

# Creates:
# - payments-prod-admins
# - payments-prod-contributors
```

### Cross-Environment Groups

```hcl
module "cross_env_groups" {
  source = "../modules/identity/groups"

  app_name = "billing"
  display_name = "Billing Service"
  environments = []  # No environment prefix

  roles = {
    admins = ["alee@contoso.com"]
    developers = ["rpatel@contoso.com"]
  }
}

# Creates:
# - billing-admins
# - billing-developers
```

## Outputs

- `groups` - Map of group keys to Azure AD object IDs
- `group_names` - Map of group keys to display names
- Groups are created even when the member list for a role is empty. This allows
  you to manage the full set of expected groups in Terraform even if some start
  without members.
