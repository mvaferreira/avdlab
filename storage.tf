resource "random_string" "random" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_storage_account" "dsc_storage_account" {
  name                     = "${var.resource_prefix}${random_string.random.id}dsc1"
  location                 = var.primary_location
  resource_group_name      = azurerm_resource_group.rg_primary.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "dsc_storage_account_container" {
  name                  = "dsc"
  storage_account_name  = azurerm_storage_account.dsc_storage_account.name
  container_access_type = "blob"
}

resource "azurerm_storage_container" "dsc_storage_account_container_scripts" {
  name                  = "scripts"
  storage_account_name  = azurerm_storage_account.dsc_storage_account.name
  container_access_type = "blob"
}

data "archive_file" "createzip" {
  type        = "zip"
  source_dir  = "CreateRootDomain"
  output_path = "CreateRootDomain.zip"
}

resource "azurerm_storage_blob" "dsc_files" {
  name                   = "createrootdomain.zip"
  storage_account_name   = azurerm_storage_account.dsc_storage_account.name
  storage_container_name = azurerm_storage_container.dsc_storage_account_container.name
  type                   = "Block"
  source                 = "createrootdomain.zip"
  depends_on             = [data.archive_file.createzip]
}

resource "azurerm_storage_blob" "script_files_configaadvm" {
  name                   = "ConfigureAADVM.ps1"
  storage_account_name   = azurerm_storage_account.dsc_storage_account.name
  storage_container_name = azurerm_storage_container.dsc_storage_account_container_scripts.name
  type                   = "Block"
  source                 = "ConfigureAADVM.ps1"
  depends_on             = [azurerm_storage_container.dsc_storage_account_container_scripts]
}

resource "azurerm_storage_blob" "script_files_creategpos_aad_connect" {
  name                   = "CreateGPOsInstallAADConnect.ps1"
  storage_account_name   = azurerm_storage_account.dsc_storage_account.name
  storage_container_name = azurerm_storage_container.dsc_storage_account_container_scripts.name
  type                   = "Block"
  source                 = "CreateGPOsInstallAADConnect.ps1"
  depends_on             = [azurerm_storage_container.dsc_storage_account_container_scripts]
}

resource "azurerm_storage_blob" "installation_creategpos_aad_connect" {
  name                   = "AADConnectProvisioningAgentSetup.exe"
  storage_account_name   = azurerm_storage_account.dsc_storage_account.name
  storage_container_name = azurerm_storage_container.dsc_storage_account_container_scripts.name
  type                   = "Block"
  source                 = "AADConnectProvisioningAgentSetup.exe"
  depends_on             = [azurerm_storage_container.dsc_storage_account_container_scripts]
}

resource "azurerm_storage_blob" "dll_file_creategpos_aad_connect" {
  name                   = "Newtonsoft.Json.dll"
  storage_account_name   = azurerm_storage_account.dsc_storage_account.name
  storage_container_name = azurerm_storage_container.dsc_storage_account_container_scripts.name
  type                   = "Block"
  source                 = "Newtonsoft.Json.dll"
  depends_on             = [azurerm_storage_container.dsc_storage_account_container_scripts]
}

resource "azurerm_storage_blob" "script_files_addstoragetodomain" {
  name                   = "AddStorageAccountDomain.ps1"
  storage_account_name   = azurerm_storage_account.dsc_storage_account.name
  storage_container_name = azurerm_storage_container.dsc_storage_account_container_scripts.name
  type                   = "Block"
  source                 = "AddStorageAccountDomain.ps1"
  depends_on             = [azurerm_storage_container.dsc_storage_account_container_scripts]
}

resource "azurerm_storage_account" "storage_account_adds" {
  name                     = "${var.resource_prefix}${random_string.random.id}adds1"
  location                 = var.primary_location
  resource_group_name      = azurerm_resource_group.rg_primary.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true

  lifecycle {
    ignore_changes = [
      azure_files_authentication
    ]
  }
}

resource "azurerm_storage_account" "storage_account_aad" {
  name                     = "${var.resource_prefix}${random_string.random.id}aad1"
  location                 = var.secondary_location
  resource_group_name      = azurerm_resource_group.rg_secondary.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true

  lifecycle {
    ignore_changes = [
      azure_files_authentication
    ]
  }
}

#File Shares

resource "azurerm_storage_share" "share_profiles_adds" {
  name                 = local.profile_share_name
  storage_account_name = azurerm_storage_account.storage_account_adds.name
  access_tier          = "Hot"
  enabled_protocol     = "SMB"
  quota                = 100
}

resource "azurerm_storage_share" "share_msixapps_adds" {
  name                 = "msixapps"
  storage_account_name = azurerm_storage_account.storage_account_adds.name
  access_tier          = "Hot"
  enabled_protocol     = "SMB"
  quota                = 100
}

resource "azurerm_storage_share" "share_profiles_aad" {
  name                 = local.profile_share_name
  storage_account_name = azurerm_storage_account.storage_account_aad.name
  access_tier          = "Hot"
  enabled_protocol     = "SMB"
  quota                = 100
}

#Private Endpoint ADDS

resource "azurerm_private_endpoint" "sa_adds_priv_endpoint" {
  name                = "${var.resource_prefix}${random_string.random.id}-adds1-file-endpoint"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name
  subnet_id           = azurerm_subnet.private_subnets_primary[0].id
  depends_on          = [azurerm_subnet.private_subnets_primary[0]]

  private_service_connection {
    name                           = "sa-adds-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.storage_account_adds.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sa-adds-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.privatedns_file.id]
  }
}

#Private Endpoint AAD

resource "azurerm_private_endpoint" "sa_aad_priv_endpoint" {
  name                = "${var.resource_prefix}${random_string.random.id}-aad1-file-endpoint"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name
  subnet_id           = azurerm_subnet.private_subnets_secondary[0].id
  depends_on          = [azurerm_subnet.private_subnets_secondary[0]]

  private_service_connection {
    name                           = "sa-aad-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.storage_account_aad.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sa-aad-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.privatedns_file.id]
  }
}