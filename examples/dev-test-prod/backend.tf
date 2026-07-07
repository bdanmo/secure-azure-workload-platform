terraform {
  # Demo uses local state. In a real deployment, state lives in the platform
  # storage account with Azure AD auth (no access keys):
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-platform-iac"
  #   storage_account_name = "contosoiaceastus2"
  #   container_name       = "tfstate"
  #   key                  = "examples/dev-test-prod.tfstate"
  #   use_azuread_auth     = true
  # }

  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

provider "azuread" {}

provider "github" {
  owner = var.github_org
}
