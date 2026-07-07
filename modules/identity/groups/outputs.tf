/*
 * Basic Outputs for Universal Groups Module
 */

# Basic group access
output "groups" {
  description = "Map of group keys to their Azure AD object IDs"
  value = {
    for key, group in azuread_group.groups : key => group.id
  }
}

output "group_names" {
  description = "Map of group keys to their display names"
  value = {
    for key, group in azuread_group.groups : key => group.display_name
  }
}


# Raw access to internal data for top-level processing
output "all_groups_data" {
  description = "Raw group data for top-level processing"
  value       = local.all_groups
}

output "all_user_members_data" {
  description = "Raw user member data for top-level processing"
  value       = local.all_user_members
}

output "all_sp_members_data" {
  description = "Raw service principal member data for top-level processing"
  value       = local.all_sp_members
}

