output "vm_id" {
  description = "ID of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "private_ip_address" {
  description = "Private IP address of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.private_ip_address
}

output "managed_identity_principal_id" {
  description = "Principal ID of the VM's managed identity"
  value       = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

output "ssh_access_group_id" {
  description = "Object ID of the SSH access group (null if not created)"
  value       = var.create_ssh_access_group ? azuread_group.ssh_access[0].object_id : null
}

output "ssh_access_group_name" {
  description = "Display name of the SSH access group (null if not created)"
  value       = var.create_ssh_access_group ? azuread_group.ssh_access[0].display_name : null
}