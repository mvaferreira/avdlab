terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.67.0"
    }

    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}