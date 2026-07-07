
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "target" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "target" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.target.name
  resource_group_name  = data.azurerm_virtual_network.target.resource_group_name
}

data "azurerm_key_vault" "main" {
  name                = var.github_app_key_vault_name
  resource_group_name = var.github_app_key_vault_rg
}

data "azurerm_key_vault" "auth" {
  name                = var.auth_key_vault_name
  resource_group_name = var.auth_key_vault_rg
}


# Auto-generate SSH keys if they don't exist in Key Vault
resource "null_resource" "ssh_key_generator" {
  # Only run if the public key secret doesn't exist
  triggers = {
    public_key_name  = "${var.vm_name}-ssh-public-key"
    private_key_name = "${var.vm_name}-ssh-private-key"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Check if public key exists
      if ! az keyvault secret show --vault-name ${var.auth_key_vault_name} --name "${var.vm_name}-ssh-public-key" >/dev/null 2>&1; then
        echo "SSH keys don't exist for ${var.vm_name}, generating..."
        
        # Generate SSH key pair
        ssh-keygen -t rsa -b 2048 -N "" -f /tmp/${var.vm_name} -C "${var.vm_name}-key"
        
        # Upload to Key Vault
        az keyvault secret set --vault-name ${var.auth_key_vault_name} --name "${var.vm_name}-ssh-public-key" --file /tmp/${var.vm_name}.pub >/dev/null
        az keyvault secret set --vault-name ${var.auth_key_vault_name} --name "${var.vm_name}-ssh-private-key" --file /tmp/${var.vm_name} >/dev/null
        
        # Clean up
        rm /tmp/${var.vm_name} /tmp/${var.vm_name}.pub
        
        echo "SSH keys generated and uploaded to Key Vault"
      else
        echo "SSH keys already exist for ${var.vm_name}, skipping generation"
      fi
    EOT
  }
}

# Reference SSH public key from Key Vault (created manually or by null_resource above)
data "azurerm_key_vault_secret" "vm_ssh_public_key" {
  depends_on = [null_resource.ssh_key_generator]

  name         = "${var.vm_name}-ssh-public-key"
  key_vault_id = data.azurerm_key_vault.auth.id
}



resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.target.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = data.azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = data.azurerm_key_vault_secret.vm_ssh_public_key.value
  }


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.tftpl", {
    enable_gh_app          = length(var.repos_to_clone) > 0
    github_app_id          = var.github_app_id
    github_installation_id = var.github_installation_id
    key_vault_name         = var.github_app_key_vault_name
    github_app_secret_name = var.github_app_kv_secret_name
    repos_to_clone         = var.repos_to_clone
    repo_clone_directory   = var.repo_clone_directory
    packages_to_install    = var.packages_to_install
    smb_mounts             = var.smb_mounts
    smb_creds              = var.smb_creds
    auth_key_vault_name    = var.auth_key_vault_name
  }))
}

# Separate UPNs and object IDs for both regular and admin users
locals {
  # Regular SSH users
  ssh_upns       = var.create_ssh_access_group ? [for user in var.ssh_users : user if contains(split("", user), "@")] : []
  ssh_object_ids = var.create_ssh_access_group ? [for user in var.ssh_users : user if !contains(split("", user), "@")] : []

  # Admin SSH users
  ssh_admin_upns       = var.create_ssh_access_group ? [for user in var.ssh_admin_users : user if contains(split("", user), "@")] : []
  ssh_admin_object_ids = var.create_ssh_access_group ? [for user in var.ssh_admin_users : user if !contains(split("", user), "@")] : []
}

# Look up regular users by UPN (only if UPNs are provided)
data "azuread_user" "ssh_users_by_upn" {
  for_each = toset(local.ssh_upns)

  user_principal_name = each.value
}

# Look up admin users by UPN (only if UPNs are provided)
data "azuread_user" "ssh_admin_users_by_upn" {
  for_each = toset(local.ssh_admin_upns)

  user_principal_name = each.value
}

# Azure AD group for SSH access (regular users)
resource "azuread_group" "ssh_access" {
  count = var.create_ssh_access_group ? 1 : 0

  display_name     = "${var.vm_name}-ssh-users"
  description      = "Users with SSH access to ${var.vm_name} (User Login role - no sudo)"
  security_enabled = true
  members = concat(
    [for user in data.azuread_user.ssh_users_by_upn : user.object_id],
    local.ssh_object_ids
  )
}

# Azure AD group for SSH admin access
resource "azuread_group" "ssh_admin_access" {
  count = var.create_ssh_access_group ? 1 : 0

  display_name     = "${var.vm_name}-ssh-admins"
  description      = "Users with SSH admin access to ${var.vm_name} (Administrator Login role - with sudo)"
  security_enabled = true
  members = concat(
    [for user in data.azuread_user.ssh_admin_users_by_upn : user.object_id],
    local.ssh_admin_object_ids
  )
}

# Virtual Machine User Login role assignment
resource "azurerm_role_assignment" "vm_user_login" {
  count = var.create_ssh_access_group ? 1 : 0

  scope                = azurerm_linux_virtual_machine.main.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = azuread_group.ssh_access[0].object_id
}

# Virtual Machine Administrator Login role assignment
resource "azurerm_role_assignment" "vm_admin_login" {
  count = var.create_ssh_access_group && length(var.ssh_admin_users) > 0 ? 1 : 0

  scope                = azurerm_linux_virtual_machine.main.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azuread_group.ssh_admin_access[0].object_id
}

# Azure AD SSH extension for keyless authentication
resource "azurerm_virtual_machine_extension" "aad_ssh" {
  name                 = "AADSSHLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
}

# Reader role assignment for SSH users on the VM's network interface
resource "azurerm_role_assignment" "nic_reader_ssh_users" {
  count = var.create_ssh_access_group ? 1 : 0

  scope                = azurerm_network_interface.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.ssh_access[0].object_id
}

# Reader role assignment for SSH admin users on the VM's network interface
resource "azurerm_role_assignment" "nic_reader_ssh_admins" {
  count = var.create_ssh_access_group ? 1 : 0

  scope                = azurerm_network_interface.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.ssh_admin_access[0].object_id
}


resource "azurerm_role_assignment" "vm_github_app_secret_access" {
  count = length(var.repos_to_clone) > 0 ? 1 : 0

  scope                = "${data.azurerm_key_vault.main.id}/secrets/${var.github_app_kv_secret_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

# Grant VM access to SMB password secret
resource "azurerm_role_assignment" "vm_smb_secret_access" {
  count = length(var.smb_mounts) > 0 ? 1 : 0

  scope                = "${data.azurerm_key_vault.auth.id}/secrets/${var.smb_creds.password_secret}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.main.identity[0].principal_id
}
