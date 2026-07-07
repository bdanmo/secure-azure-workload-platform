/*
 * Outputs for the example app root
 * - Expose raw module outputs for platform tooling to consume via remote_state
 */

output "payments" {
  description = "Application metadata, infrastructure details (RG/KV names and IDs), Azure AD groups with members and permissions, OIDC service principal details, and backend configuration"
  value       = module.app.application_payload
}

output "dev_vm" {
  description = "Dev utility VM details"
  value = {
    id                    = module.dev_vm.vm_id
    private_ip            = module.dev_vm.private_ip_address
    ssh_access_group_name = module.dev_vm.ssh_access_group_name
  }
}
