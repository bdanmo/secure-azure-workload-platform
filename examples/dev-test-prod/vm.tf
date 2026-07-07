# Utility VM for the workload's dev environment.
# Network and auth Key Vault are pre-existing shared infrastructure —
# see variables in modules/compute/linux_vm for the defaults being used here.
module "dev_vm" {
  source = "../../modules/compute/linux_vm"

  vm_name        = "vm-payments-dev"
  vm_size        = "Standard_B4ms"
  admin_username = "azureuser"

  resource_group_name = module.app.resource_group_names["dev"]

  ssh_users       = ["rpatel@contoso.com"]
  ssh_admin_users = ["alee@contoso.com"]

  packages_to_install = [
    "git",
    "htop"
  ]
}
