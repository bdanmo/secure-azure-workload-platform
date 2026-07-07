/*
 * Application groups (inline, no wrapper)
 */

locals {
  cross_env_roles = merge(
    var.admin_users != null && length(var.admin_users) > 0 ? { admins = var.admin_users } : {},
    var.include_developers_group ? { developers = var.developers } : {}
  )
}

# Cross-environment groups (admins, developers)
module "cross_env_groups" {
  source = "../identity/groups"

  app_name     = var.app_name
  display_name = var.display_name
  environments = []
  roles        = local.cross_env_roles
}

locals {
  groups = module.cross_env_groups.groups

  group_details = {
    for key, group_data in module.cross_env_groups.all_groups_data :
    module.cross_env_groups.group_names[key] => {
      object_id = module.cross_env_groups.groups[key]
      members   = tolist(group_data.members)
    }
  }
}

# Add the app's admin group to terraform state readers
resource "azuread_group_member" "admin_group_state_reader" {
  count            = contains(keys(local.groups), "admins") && var.state_readers_group_object_id != null ? 1 : 0
  group_object_id  = var.state_readers_group_object_id
  member_object_id = local.groups["admins"]
}
