variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "resource_prefix" {
  type    = string
  default = "avd"
}

variable "primary_location" {
  type    = string
  default = "eastus"

  validation {
    condition     = contains(["centralindia", "uksouth", "ukwest", "japaneast", "australiaeast", "canadaeast", "canadacentral", "northeurope", "westeurope", "eastus", "eastus2", "westus", "westus2", "westus3", "northcentralus", "southcentralus", "westcentralus", "centralus"], var.primary_location)
    error_message = "Invalid primary location. Please choose a valid location for AVD."
  }
}

variable "secondary_location" {
  type    = string
  default = "westus"

  validation {
    condition     = contains(["centralindia", "uksouth", "ukwest", "japaneast", "australiaeast", "canadaeast", "canadacentral", "northeurope", "westeurope", "eastus", "eastus2", "westus", "westus2", "westus3", "northcentralus", "southcentralus", "westcentralus", "centralus"], var.secondary_location)
    error_message = "Invalid secondary location. Please choose a valid location for AVD."
  }
}

variable "primary_vnet_address_space" {
  type    = string
  default = "10.20.0.0/16"
}

variable "secondary_vnet_address_space" {
  type    = string
  default = "10.30.0.0/16"
}

variable "admin_username" {
  type    = string
  default = "localadm"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type    = string
  default = "contoso.com"
}

variable "vmcount" {
  type    = number
  default = 1
}

variable "vmsize" {
  type    = string
  default = "Standard_B2s"
}

variable "dcsize" {
  type = string
  default = "Standard_B4ms"
}

variable "cloud_admin" {
  type    = string
  default = "cloudadmin"
}

variable "cloud_admin_password" {
  type = string
}

variable "tenant_name" {
  type = string
}

variable "deploy_personal" {
  type    = number
  default = 0
  validation {
    condition     = var.deploy_personal == 0 || var.deploy_personal == 1
    error_message = "deploy_personal accepts 0 (don't deploy) or 1 (deploy)."
  }
}

variable "deploy_hybrid" {
  type    = number
  default = 0
  validation {
    condition     = var.deploy_hybrid == 0 || var.deploy_hybrid == 1
    error_message = "deploy_hybrid accepts 0 (don't deploy) or 1 (deploy)."
  }
}

variable "deploy_aad" {
  type    = number
  default = 0
  validation {
    condition     = var.deploy_aad == 0 || var.deploy_aad == 1
    error_message = "deploy_aad accepts 0 (don't deploy) or 1 (deploy)."
  }
}

resource "random_string" "avd_local_password" {
  length           = 12
  special          = true
  min_special      = 2
  min_lower        = 2
  min_numeric      = 2
  min_upper        = 2
  override_special = "*!@#?"
}

locals {
  local_password              = var.admin_password != "" ? var.admin_password : random_string.avd_local_password.result
  local_cloudadmin_password   = var.cloud_admin_password != "" ? var.cloud_admin_password : random_string.avd_local_password.result
  prefix                      = var.resource_prefix
  private_subnets_primary     = data.template_file.calculate_priv_subnets_primary.*.rendered
  private_subnets_secondary   = data.template_file.calculate_priv_subnets_secondary.*.rendered
  priv_subnet_count           = 2
  profile_share_name          = "profiles"
  computers_oupath            = "OU=Computers,OU=Lab,DC=${split(".", var.domain_name)[0]},DC=${split(".", var.domain_name)[1]}"
  avd_agents_url              = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02411.177.zip"
  dsc_endpoint                = "https://${azurerm_storage_account.dsc_storage_account.name}.blob.core.windows.net/dsc/createrootdomain.zip"
  aad_script                  = "https://${azurerm_storage_account.dsc_storage_account.name}.blob.core.windows.net/scripts/ConfigureAADVM.ps1"
  creategposaadconnect_script = "https://${azurerm_storage_account.dsc_storage_account.name}.blob.core.windows.net/scripts/CreateGPOsInstallAADConnect.ps1"
  addstoragetodomain_script   = "https://${azurerm_storage_account.dsc_storage_account.name}.blob.core.windows.net/scripts/AddStorageAccountDomain.ps1"
}

output "passwd" {
  value = random_string.avd_local_password.result
}