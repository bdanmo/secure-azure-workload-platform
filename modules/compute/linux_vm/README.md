# Linux VM Module

Creates a Linux virtual machine with Azure AD SSH authentication (keyless), optional GitHub App integration for repository cloning, and Azure AD group-based access management.

## Features

- **Azure AD SSH Authentication**: Keyless SSH using Azure AD identities - no private keys in state or Key Vault
- **Azure AD Group Management**: Creates Azure AD group with VM login permissions
- **GitHub App Integration**: Optional repository cloning using shared, pre-existing GitHub App. Off by default.
- **SMB Mount Support**: Optional on-premises SMB share mounting with secure credential management
- **Managed Identity**: System-assigned managed identity for VM operations
- **Network Flexibility**: Configurable VNet, subnet, and resource group placement
- **Bootstrap Automation**: Cloud-init script for package installation and repository setup

## Basic Usage

```hcl
module "simple_vm" {
  source = "../modules/compute/linux_vm"

  vm_name        = "my-vm"
  vm_size        = "Standard_B2s"
  admin_username = "azureuser"

  packages_to_install = [
    "postgresql"
  ]
}
```

## SSH Access Management

The module supports two-tier SSH access control:

### Regular SSH Users (No Sudo)

```hcl
module "vm_with_regular_users" {
  source = "../modules/compute/linux_vm"

  vm_name        = "my-vm"
  vm_size        = "Standard_B2s"
  admin_username = "azureuser"

  # Regular users - can login but no sudo access
  ssh_users = [
    "developer1@contoso.com",
    "developer2@contoso.com"
  ]

  packages_to_install = ["postgresql"]
}
```

### Admin SSH Users (With Sudo)

```hcl
module "vm_with_admin_users" {
  source = "../modules/compute/linux_vm"

  vm_name        = "my-vm"
  vm_size        = "Standard_B2s"
  admin_username = "azureuser"

  # Admin users - full sudo access
  ssh_admin_users = [
    "admin1@contoso.com",
    "admin2@contoso.com"
  ]

  packages_to_install = ["postgresql"]
}
```

**User Identity Formats:**

- **UPNs**: `"user@contoso.com"` (requires Graph permissions)
- **Object IDs**: `"12345678-1234-1234-1234-123456789012"` (no Graph permissions needed)

## GitHub App Integration

GitHub App integration is **automatic** - simply specify repositories to clone:

```hcl
module "backup_vm" {
  source = "../modules/compute/linux_vm"

  vm_name        = "backup-vm"
  vm_size        = "Standard_B2s"
  admin_username = "azureuser"

  # GitHub App integration enabled automatically when repos specified
  repos_to_clone = [
    "contoso-eng/repo1",
    "contoso-eng/repo2"
  ]
  repo_clone_directory = "/opt/backups" # Optional
}
```

**No `enable_gh_app` needed** - if `repos_to_clone` is empty or not specified, no GitHub integration occurs.

## SMB Mount Integration

Mount on-premises SMB shares with secure credential management:

```hcl
module "vm_with_smb" {
  source = "../modules/compute/linux_vm"

  vm_name        = "backup-vm"
  vm_size        = "Standard_B2s"
  admin_username = "azureuser"

  # SMB credentials (stored in Key Vault)
  smb_creds = {
    username        = "contoso\\svc_files_app" # or "svc_files_app@contoso.com"
    password_secret = "sp-svc-files-app-password"
  }

  # Multiple SMB mounts using same credentials
  smb_mounts = [
    {
      local_path = "/mnt/data"
      smb_path   = "//fileserver.contoso.com/data"
    },
    {
      local_path    = "/mnt/archive"
      smb_path      = "//fileserver.contoso.com/archive"
      mount_options = "vers=3.0,dir_mode=0777,file_mode=0777,uid=1000,gid=1000" # Custom permissions
    }
  ]

  packages_to_install = ["postgresql"]
}
```

**SMB Mount Features:**

- **Secure credentials**: Username/password stored in Azure Key Vault
- **Multiple mounts**: One set of credentials for multiple mount points
- **Automatic setup**: `cifs-utils` installed automatically, mounts added to `/etc/fstab`
- **Custom permissions**: Override default mount options per mount point

## Custom Network Configuration

```hcl
module "custom_vm" {
  source = "../modules/compute/linux_vm"

  vm_name                  = "custom-vm"
  vm_size                  = "Standard_B2s"
  admin_username           = "azureuser"
  resource_group_name      = "my-custom-rg"
  vnet_name                = "my-vnet"
  vnet_resource_group_name = "network-rg"
  subnet_name              = "my-subnet"
  packages_to_install      = []
}
```

## Variables

### Required Variables

| Name | Type | Description |
|------|------|-------------|
| `vm_name` | `string` | Name of the virtual machine |
| `vm_size` | `string` | Azure VM size |
| `admin_username` | `string` | Admin username for the VM |
| `packages_to_install` | `list(string)` | List of packages to install via apt |

### Optional Variables

#### VM Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `os_disk_size_gb` | `number` | `30` | Size of the OS disk in GB |
| `os_disk_storage_account_type` | `string` | `"StandardSSD_LRS"` | Storage type for OS disk. Premium_LRS requires VM sizes with 's' (DS, ES, FS) or B-series |

#### Network Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `resource_group_name` | `string` | `"contososervers"` | Resource group name where VM will be created |
| `vnet_name` | `string` | `"ContosoAzureProd"` | Virtual network name |
| `vnet_resource_group_name` | `string` | `"rg-network-core"` | Resource group containing the virtual network |
| `subnet_name` | `string` | `"ApplicationA"` | Subnet name within the virtual network |

#### Key Vault Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `github_app_key_vault_name` | `string` | `"kv-platform-iac"` | Name of Key Vault containing shared GitHub App private key |
| `github_app_key_vault_rg` | `string` | `"rg-platform-iac"` | Resource group for the GitHub App Key Vault |
| `auth_key_vault_name` | `string` | `"kv-contososervers"` | Name of Key Vault for SSH keys and SMB credentials |
| `auth_key_vault_rg` | `string` | `"contososervers"` | Resource group of authentication Key Vault |

#### GitHub App Integration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `github_app_id` | `string` | `""` | GitHub App ID for repository access |
| `github_installation_id` | `string` | `""` | GitHub App Installation ID |
| `github_app_kv_secret_name` | `string` | `"github-platform-sync-pk"` | Name of shared GitHub App private key secret in Key Vault |
| `repos_to_clone` | `list(string)` | `[]` | List of repositories to clone (format: "org/repo"). GitHub App integration is automatic when non-empty. |
| `repo_clone_directory` | `string` | `"/usr/local/repos"` | Directory where repositories will be cloned |

#### SSH Access Management

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `create_ssh_access_group` | `bool` | `true` | Create Azure AD groups for SSH access to this VM |
| `ssh_users` | `list(string)` | `[]` | List of users for SSH access (User Login role - no sudo). Can be UPNs (requires Graph permissions) or object IDs |
| `ssh_admin_users` | `list(string)` | `[]` | List of users for SSH admin access (Administrator Login role - with sudo). Can be UPNs (requires Graph permissions) or object IDs |

#### SMB Mount Configuration

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `smb_creds` | `object` | `null` | SMB credentials object with `username` (string) and `password_secret` (string - Key Vault secret name). Required if `smb_mounts` is specified. |
| `smb_mounts` | `list(object)` | `[]` | List of SMB mount configurations. Each object contains `local_path` (string), `smb_path` (string), and optional `mount_options` (string, default: "vers=3.0,dir_mode=0755,file_mode=0644,uid=1000,gid=1000") |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `vm_id` | `string` | ID of the virtual machine |
| `vm_name` | `string` | Name of the virtual machine |
| `private_ip_address` | `string` | Private IP address of the virtual machine |
| `managed_identity_principal_id` | `string` | Principal ID of the VM's managed identity |
| `ssh_access_group_id` | `string` | Object ID of the SSH access group (null if not created) |
| `ssh_access_group_name` | `string` | Display name of the SSH access group (null if not created) |

## Security Model

- **SSH Keys**: Auto-generated in Azure Key Vault if missing, never stored in Terraform state
- **Two-Tier SSH Access Control**: Azure AD group-based access with role separation
  - **Regular SSH users** (`ssh_users`): "Virtual Machine User Login" role - can login but no sudo
  - **Admin SSH users** (`ssh_admin_users`): "Virtual Machine Administrator Login" role - full sudo access
  - Both groups get Azure AD SSH authentication (keyless)
  - VM itself has no Key Vault permissions (access is user-based via AAD SSH)
- **GitHub App**: Uses shared private key to generate short-lived tokens (1 hour expiry) on-demand
- **Network Security**: VM placed in specified subnet with no public IP by default

### SSH Access Methods

**Option 1: Direct SSH (Recommended)**

```bash
# Install Azure CLI SSH extension (one-time setup)
az extension add --name ssh

# SSH directly using Azure AD authentication
az ssh vm --resource-group contososervers --name my-vm --local-user azureuser
```

**Option 2: Via Bastion CLI**

```bash
# SSH via Bastion using Azure AD authentication
az network bastion ssh \
  --name <bastion-name> --resource-group <bastion-rg> \
  --target-resource-id <vm-resource-id> \
  --auth-type AAD --username azureuser
```

**Benefits of Azure AD SSH:**

- ✅ **No private keys** - Nothing stored in Terraform state or Key Vault
- ✅ **MFA support** - Inherits your Azure AD authentication policies
- ✅ **Audit trail** - SSH sessions logged in Azure AD sign-in logs
- ✅ **Conditional Access** - Apply policies like device compliance, location restrictions

## Prerequisites

- Azure Key Vault (default `kv-contososervers`) for SSH key storage and SMB credentials
- Azure Key Vault (default `kv-platform-iac`) with shared GitHub App private key (if using GitHub integration)
- Pre-existing GitHub App with repository access (managed outside Terraform)
- Virtual network and subnet must exist
- Resource group must exist
- Azure CLI with SSH extension for SSH access (`az extension add --name ssh`)
- For SMB mounts: SMB credentials stored in Key Vault

## SSH Key Management

**SSH keys are automatically managed:**

- **Auto-generation**: If SSH keys don't exist in Key Vault, they're generated during `terraform apply`
- **Key Vault storage**: Keys stored in the auth Key Vault as `<vm-name>-ssh-public-key` and `<vm-name>-ssh-private-key`
- **No manual setup required** - keys are created on first deployment

### Manual SSH Key Setup (Optional)

If you prefer to manually create keys before deployment:

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 2048 -N "" -f <vm-name> -C "<vm-name>-key"

# Upload to Key Vault
az keyvault secret set --vault-name <auth-key-vault> --name "<vm-name>-ssh-public-key" --file <vm-name>.pub
az keyvault secret set --vault-name <auth-key-vault> --name "<vm-name>-ssh-private-key" --file <vm-name>

# Clean up local files
rm <vm-name> <vm-name>.pub
```

**Security Benefits:**

- ✅ No private keys in Terraform state
- ✅ Keys stored centrally in Key Vault
- ✅ Emergency access via Bastion portal
- ✅ Backup/recovery from Key Vault

## Examples

See `examples/dev-test-prod` for a complete example.
