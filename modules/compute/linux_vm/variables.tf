variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "vm_size" {
  description = "Size of the VM"
  type        = string
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
}


variable "resource_group_name" {
  description = "Resource group name where VM will be created"
  type        = string
  default     = "contososervers"
}

variable "vnet_name" {
  description = "Virtual network name"
  type        = string
  default     = "ContosoAzureProd"
}

variable "vnet_resource_group_name" {
  description = "Resource group name containing the virtual network"
  type        = string
  default     = "rg-network-core"
}

variable "subnet_name" {
  description = "Subnet name within the virtual network"
  type        = string
  default     = "ApplicationA"
}

variable "github_app_key_vault_name" {
  description = "Name of the Key Vault containing GitHub App private key"
  type        = string
  default     = "kv-platform-iac"
}

variable "github_app_key_vault_rg" {
  description = "Resource group name for the Key Vault containing GitHub App private key"
  type        = string
  default     = "rg-platform-iac"
}

variable "auth_key_vault_name" {
  description = "Name of Key Vault for SSH keys and SMB credentials storage"
  type        = string
  default     = "kv-contososervers"
}

variable "auth_key_vault_rg" {
  description = "Resource group of authentication Key Vault"
  type        = string
  default     = "contososervers"
}

variable "github_app_id" {
  description = "GitHub App ID for repository access"
  type        = string
  default     = ""
}

variable "github_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  default     = ""
}

variable "github_app_kv_secret_name" {
  description = "Name of the GitHub App secret in the Key Vault"
  type        = string
  default     = "github-platform-sync-pk"
}

variable "repos_to_clone" {
  description = "List of repositories to clone during bootstrap"
  type        = list(string)
  default     = []
}

variable "repo_clone_directory" {
  description = "Directory where repositories will be cloned"
  type        = string
  default     = "/usr/local/repos"
}

variable "packages_to_install" {
  description = "List of packages to install via apt"
  type        = list(string)
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 30
}

variable "os_disk_storage_account_type" {
  description = "Storage account type for OS disk. Premium_LRS requires VM sizes with 's' in name (DS, ES, FS, etc.) or B-series. StandardSSD_LRS works with all VM sizes."
  type        = string
  default     = "StandardSSD_LRS"

  validation {
    condition = contains([
      "Standard_LRS",
      "StandardSSD_LRS",
      "Premium_LRS",
      "StandardSSD_ZRS",
      "Premium_ZRS"
    ], var.os_disk_storage_account_type)
    error_message = "Storage account type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS, StandardSSD_ZRS, Premium_ZRS."
  }
}


variable "create_ssh_access_group" {
  description = "Create an Azure AD group for SSH access to this VM"
  type        = bool
  default     = true
}

variable "ssh_users" {
  description = "List of users to add to the SSH access group (User Login role - no sudo). Can be UPNs (e.g., 'user@contoso.com') or object IDs (e.g., '12345678-1234-1234-1234-123456789012'). UPNs require Graph permissions, object IDs do not."
  type        = list(string)
  default     = []
}

variable "ssh_admin_users" {
  description = "List of users to add to the SSH admin group (Administrator Login role - with sudo). Can be UPNs (e.g., 'user@contoso.com') or object IDs (e.g., '12345678-1234-1234-1234-123456789012'). UPNs require Graph permissions, object IDs do not."
  type        = list(string)
  default     = []
}

variable "smb_creds" {
  description = "Object containing username and name of password kv secret"
  type = object({
    username        = string
    password_secret = string
  })
  default = null
}

variable "smb_mounts" {
  description = "List of SMB mount configurations"
  type = list(object({
    local_path    = string # /mnt/qo
    smb_path      = string # //server.domain.com/share
    mount_options = optional(string, "vers=3.0,dir_mode=0755,file_mode=0644,uid=1000,gid=1000")
  }))
  default = []
}
