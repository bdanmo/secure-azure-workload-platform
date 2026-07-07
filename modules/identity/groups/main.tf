/*
 * Universal Groups Module
 * 
 * This module can create Azure AD groups using two modes:
 * 1. Dynamic mode: auto-generate groups with prefix + roles + environments
 * 2. Custom mode: manually define specific groups with custom names
 * 
 * This universal module is used by both identity and platform workspaces.
 */

terraform {
  required_version = ">= 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

locals {
  # Cross-environment roles (always without environment prefix)
  cross_env_roles = ["admins", "developers"]

  # Generate group keys and names for dynamic mode (roles + environments)
  dynamic_groups = merge(
    # Cross-environment groups (admins, developers)
    {
      for role in keys(var.roles) :
      role => {
        role        = role
        environment = ""
        name        = "${var.app_name}-${role}"
        description = "${var.display_name} ${title(role)}"
        members     = var.roles[role]
      }
      if contains(local.cross_env_roles, role)
    },
    # Environment-specific groups (other roles)
    {
      for combo in setproduct([for role in keys(var.roles) : role if !contains(local.cross_env_roles, role)], length(var.environments) > 0 ? var.environments : [""]) :
      "${combo[0]}${combo[1] != "" ? "-${combo[1]}" : ""}" => {
        role        = combo[0]
        environment = combo[1]
        name        = "${var.app_name}${combo[1] != "" ? "-${combo[1]}" : ""}-${combo[0]}"
        description = "${var.display_name}${combo[1] != "" ? " ${title(combo[1])}" : ""} ${title(combo[0])}"
        members     = var.roles[combo[0]]
      }
    }
  )

  # Use dynamic groups (simplified for now)
  all_groups = local.dynamic_groups

  # Flatten all members for data source lookups
  # Detection: "user@domain" → user, "group:name" → group, everything else → service principal
  all_user_members = flatten([
    for group_key, group in local.all_groups : [
      for member in group.members : {
        group_key = group_key
        member    = member
        key       = "${group_key}_${member}"
      }
      if can(regex("@", member))
    ]
  ])

  all_group_members = flatten([
    for group_key, group in local.all_groups : [
      for member in group.members : {
        group_key    = group_key
        display_name = trimprefix(member, "group:")
        key          = "${group_key}_${member}"
      }
      if startswith(member, "group:")
    ]
  ])

  all_sp_members = flatten([
    for group_key, group in local.all_groups : [
      for member in group.members : {
        group_key = group_key
        member    = member
        key       = "${group_key}_${member}"
      }
      if !can(regex("@", member)) && !startswith(member, "group:")
    ]
  ])
}

# Data sources for user lookups
data "azuread_user" "user_members" {
  for_each            = { for item in local.all_user_members : item.key => item }
  user_principal_name = each.value.member
}

# Data sources for group lookups (group:name members)
data "azuread_group" "group_members" {
  for_each     = { for item in local.all_group_members : item.key => item }
  display_name = each.value.display_name
}

# Data sources for service principal lookups
data "azuread_service_principal" "sp_members" {
  for_each     = { for item in local.all_sp_members : item.key => item }
  display_name = each.value.member
}

# client configuration
data "azurerm_client_config" "current" {}

# Create the groups
resource "azuread_group" "groups" {
  for_each = local.all_groups

  display_name     = each.value.name
  description      = each.value.description
  security_enabled = true

  owners = [
    data.azurerm_client_config.current.object_id
  ]

  lifecycle {
    ignore_changes = [
      members # We manage members separately
    ]
  }
}

# Add user members to groups
resource "azuread_group_member" "user_members" {
  for_each = { for item in local.all_user_members : item.key => item }

  group_object_id  = azuread_group.groups[each.value.group_key].id
  member_object_id = data.azuread_user.user_members[each.key].id
}

# Add group members to groups (nested group membership)
resource "azuread_group_member" "group_members" {
  for_each = { for item in local.all_group_members : item.key => item }

  group_object_id  = azuread_group.groups[each.value.group_key].id
  member_object_id = data.azuread_group.group_members[each.key].id
}

# Add service principal members to groups
resource "azuread_group_member" "sp_members" {
  for_each = { for item in local.all_sp_members : item.key => item }

  group_object_id  = azuread_group.groups[each.value.group_key].id
  member_object_id = data.azuread_service_principal.sp_members[each.key].id
}


