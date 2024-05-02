resource "time_rotating" "avd_token" {
  rotation_days = 30
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "hostpool_registration_adds" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avdtfpool_adds.id
  expiration_date = time_rotating.avd_token.rotation_rfc3339
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "hostpool_registration_adds_win11p" {
  count           = var.deploy_personal
  hostpool_id     = azurerm_virtual_desktop_host_pool.avdtfpool_adds_win11p[0].id
  expiration_date = time_rotating.avd_token.rotation_rfc3339
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "hostpool_registration_aad" {
  count           = var.deploy_aad
  hostpool_id     = azurerm_virtual_desktop_host_pool.avdtfpool_aad[0].id
  expiration_date = time_rotating.avd_token.rotation_rfc3339
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "hostpool_registration_haadj" {
  count           = var.deploy_hybrid
  hostpool_id     = azurerm_virtual_desktop_host_pool.avdtfpool_haadj[0].id
  expiration_date = time_rotating.avd_token.rotation_rfc3339
}

locals {
  registration_token_adds        = azurerm_virtual_desktop_host_pool_registration_info.hostpool_registration_adds.token
  registration_token_adds_win11p = var.deploy_personal == 1 ? azurerm_virtual_desktop_host_pool_registration_info.hostpool_registration_adds_win11p[0].token : 0
  registration_token_aad         = var.deploy_aad == 1 ? azurerm_virtual_desktop_host_pool_registration_info.hostpool_registration_aad[0].token : 0
  registration_token_haadj       = var.deploy_hybrid == 1 ? azurerm_virtual_desktop_host_pool_registration_info.hostpool_registration_haadj[0].token : 0
}

#VMs ADDS
resource "azurerm_windows_virtual_machine" "avdvms_adds" {
  count                    = var.vmcount
  name                     = "${var.resource_prefix}-adds-vm${count.index + 1}"
  computer_name            = "${var.resource_prefix}-adds-vm${count.index + 1}"
  resource_group_name      = azurerm_resource_group.rg_primary.name
  location                 = var.primary_location
  size                     = var.vmsize
  admin_username           = var.admin_username
  admin_password           = local.local_password
  license_type             = "Windows_Client"
  enable_automatic_updates = false
  patch_mode               = "Manual"

  boot_diagnostics {
    storage_account_uri = ""
  }

  network_interface_ids = [azurerm_network_interface.avdvmnic_adds[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.resource_prefix}-vm-${count.index + 1}-adds-osdisk"
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_id = azurerm_shared_image_version.compute_gallery_version_win10.id

  depends_on = [azurerm_virtual_network_dns_servers.dnsserver_dc_primary]
}

resource "azurerm_virtual_machine_extension" "avdvms_joindomain_adds" {
  count                      = var.vmcount
  name                       = "${var.resource_prefix}-joindomain-vm${count.index + 1}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_adds[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.dsc_domain]

  settings = <<SETTINGS
    {
      "Name": "${var.domain_name}",
      "OUPath": "${local.computers_oupath}",
      "User": "avdadmin@${var.domain_name}",
      "Restart": "true",
      "Options": "3"
    }
    SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Password":"${local.local_password}"
    }
    PROTECTED_SETTINGS

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

resource "azurerm_virtual_machine_extension" "avdvms_dsc_adds" {
  count                      = var.vmcount
  name                       = "${var.resource_prefix}-joinavdpool-vm${count.index + 1}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_adds[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "modulesUrl": "${local.avd_agents_url}",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "hostPoolName": "${azurerm_virtual_desktop_host_pool.avdtfpool_adds.name}",
        "registrationInfoToken": "${local.registration_token_adds}"
      }
    }
    SETTINGS

  lifecycle {
    ignore_changes = [settings]
  }

  depends_on = [azurerm_virtual_machine_extension.avdvms_joindomain_adds]
}

resource "azurerm_virtual_machine_extension" "add_storage_account_domain" {
  name                       = "addstoragetodomain"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_adds[0].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.dsc_domain, azurerm_virtual_machine_extension.creategpos_aad_connect, azurerm_storage_blob.script_files_addstoragetodomain, azurerm_storage_share.share_profiles_adds, azurerm_storage_share.share_profiles_aad, azurerm_role_assignment.role_assignment_vmadds_contributor, azurerm_role_assignment.role_assignment_vmadds_contributor_sec]

  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell.exe -NoLogo -NoProfile -Command \"./AddStorageAccountDomain.ps1 -DomainName ${var.domain_name} -StorageAccountName ${azurerm_storage_account.storage_account_adds.name} -ShareName ${local.profile_share_name} -StorageAccountNameAAD ${azurerm_storage_account.storage_account_aad.name} -SubscriptionId ${var.subscription_id} -TenantId ${var.tenant_id} -ResourceGroupName ${azurerm_resource_group.rg_primary.name} -ResourceGroupSecName ${azurerm_resource_group.rg_secondary.name} -LocalUsername ${var.admin_username} -LocalPasswd ${local.local_password} -DCName ${azurerm_windows_virtual_machine.domain_controller.name};\""
    }
  PROTECTED_SETTINGS

  settings = <<SETTINGS
    {
        "fileUris": [
          "${local.addstoragetodomain_script}"
        ]
    }
  SETTINGS
}

#VMs AAD
resource "azurerm_windows_virtual_machine" "avdvms_aad" {
  count                    = var.deploy_aad
  name                     = "${var.resource_prefix}-aad-vm${count.index}"
  computer_name            = "${var.resource_prefix}-aad-vm${count.index}"
  resource_group_name      = azurerm_resource_group.rg_secondary.name
  location                 = var.secondary_location
  size                     = var.vmsize
  admin_username           = var.admin_username
  admin_password           = local.local_password
  license_type             = "Windows_Client"
  enable_automatic_updates = false
  patch_mode               = "Manual"

  network_interface_ids = [azurerm_network_interface.avdvmnic_aad[count.index].id]

  boot_diagnostics {
    storage_account_uri = ""
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.resource_prefix}-vm-${count.index}-aad-osdisk"
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_id = azurerm_shared_image_version.compute_gallery_version_win10.id

  depends_on = [azurerm_virtual_network_dns_servers.dnsserver_dc_primary]
}

resource "azurerm_virtual_machine_extension" "avdvms_joindomain_aad" {
  count                      = var.deploy_aad
  name                       = "${var.resource_prefix}-joindomain-vm${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_aad[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "avdvms_dsc_aad" {
  count                      = var.deploy_aad
  name                       = "${var.resource_prefix}-joinavdpool-vm${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_aad[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "modulesUrl": "${local.avd_agents_url}",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "hostPoolName": "${azurerm_virtual_desktop_host_pool.avdtfpool_aad[0].name}",
        "registrationInfoToken": "${local.registration_token_aad}"
      }
    }
    SETTINGS

  lifecycle {
    ignore_changes = [settings]
  }

  depends_on = [azurerm_virtual_machine_extension.avdvms_joindomain_aad]
}

resource "azurerm_virtual_machine_extension" "avdvms_vmconfig_aad" {
  count                      = var.deploy_aad
  name                       = "${var.resource_prefix}-vmconfig-vm${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_aad[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_windows_virtual_machine.avdvms_aad, azurerm_storage_blob.script_files_configaadvm]

  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell.exe -Command \"./ConfigureAADVM.ps1 -StorageAccountName ${azurerm_storage_account.storage_account_aad.name} -ShareName ${local.profile_share_name} -LocalAdmin ${var.admin_username};\""
    }
  PROTECTED_SETTINGS

  settings = <<SETTINGS
    {
        "fileUris": [
          "${local.aad_script}"
        ]
    }
  SETTINGS
}

#VMs ADDS+AzureAD Hybrid
resource "azurerm_windows_virtual_machine" "avdvms_haadj" {
  count                    = var.deploy_hybrid
  name                     = "${var.resource_prefix}-haadj-vm${count.index}"
  computer_name            = "${var.resource_prefix}-haadj-vm${count.index}"
  resource_group_name      = azurerm_resource_group.rg_primary.name
  location                 = var.primary_location
  size                     = var.vmsize
  admin_username           = var.admin_username
  admin_password           = local.local_password
  license_type             = "Windows_Client"
  enable_automatic_updates = false
  patch_mode               = "Manual"

  boot_diagnostics {
    storage_account_uri = ""
  }

  network_interface_ids = [azurerm_network_interface.avdvmnic_haadj[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.resource_prefix}-vm-${count.index}-haadj-osdisk"
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_id = azurerm_shared_image_version.compute_gallery_version_win10.id

  depends_on = [azurerm_virtual_network_dns_servers.dnsserver_dc_primary]
}

resource "azurerm_virtual_machine_extension" "avdvms_joindomain_haadj" {
  count                      = var.deploy_hybrid
  name                       = "${var.resource_prefix}-joindomain-vm${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_haadj[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.dsc_domain]

  settings = <<SETTINGS
    {
      "Name": "${var.domain_name}",
      "OUPath": "${local.computers_oupath}",
      "User": "avdadmin@${var.domain_name}",
      "Restart": "true",
      "Options": "3"
    }
    SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Password":"${local.local_password}"
    }
    PROTECTED_SETTINGS

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

resource "azurerm_virtual_machine_extension" "avdvms_dsc_haadj" {
  count                      = var.deploy_hybrid
  name                       = "${var.resource_prefix}-joinavdpool-vm${count.index + 1}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_haadj[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "modulesUrl": "${local.avd_agents_url}",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "hostPoolName": "${azurerm_virtual_desktop_host_pool.avdtfpool_haadj[0].name}",
        "registrationInfoToken": "${local.registration_token_haadj}"
      }
    }
    SETTINGS

  lifecycle {
    ignore_changes = [settings]
  }

  depends_on = [azurerm_virtual_machine_extension.avdvms_joindomain_haadj]
}

resource "azurerm_virtual_machine_extension" "avdvms_vmconfig_haadj" {
  count                      = var.deploy_hybrid
  name                       = "${var.resource_prefix}-vmconfig-vm${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_haadj[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_windows_virtual_machine.avdvms_haadj, azurerm_storage_blob.script_files_configaadvm]

  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell.exe -Command \"./ConfigureAADVM.ps1 -StorageAccountName ${azurerm_storage_account.storage_account_adds.name} -ShareName ${local.profile_share_name} -LocalAdmin ${var.admin_username};\""
    }
  PROTECTED_SETTINGS

  settings = <<SETTINGS
    {
        "fileUris": [
          "${local.aad_script}"
        ]
    }
  SETTINGS
}

#Windows11 Personal
resource "azurerm_windows_virtual_machine" "avdvms_adds_win11p" {
  count                    = var.deploy_personal
  name                     = "${var.resource_prefix}-adds-vmp${count.index}"
  computer_name            = "${var.resource_prefix}-adds-vmp${count.index}"
  resource_group_name      = azurerm_resource_group.rg_primary.name
  location                 = var.primary_location
  size                     = var.vmsize
  admin_username           = var.admin_username
  admin_password           = local.local_password
  license_type             = "Windows_Client"
  enable_automatic_updates = false
  patch_mode               = "Manual"

  boot_diagnostics {
    storage_account_uri = ""
  }

  network_interface_ids = [azurerm_network_interface.avdvmnic_adds_win11p[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.resource_prefix}-vm-${count.index}-adds-win11p-osdisk"
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_id = azurerm_shared_image_version.compute_gallery_version_win11[0].id

  depends_on = [azurerm_virtual_network_dns_servers.dnsserver_dc_primary]
}

resource "azurerm_virtual_machine_extension" "avdvms_joindomain_adds_win11p" {
  count                      = var.deploy_personal
  name                       = "${var.resource_prefix}-joindomain-vm${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_adds_win11p[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.dsc_domain]

  settings = <<SETTINGS
    {
      "Name": "${var.domain_name}",
      "OUPath": "${local.computers_oupath}",
      "User": "avdadmin@${var.domain_name}",
      "Restart": "true",
      "Options": "3"
    }
    SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Password":"${local.local_password}"
    }
    PROTECTED_SETTINGS

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

resource "azurerm_virtual_machine_extension" "avdvms_dsc_adds_win11p" {
  count                      = var.deploy_personal
  name                       = "${var.resource_prefix}-joinavdpool-vm${count.index}"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdvms_adds_win11p[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "modulesUrl": "${local.avd_agents_url}",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "hostPoolName": "${azurerm_virtual_desktop_host_pool.avdtfpool_adds_win11p[0].name}",
        "registrationInfoToken": "${local.registration_token_adds_win11p}"
      }
    }
    SETTINGS

  lifecycle {
    ignore_changes = [settings]
  }

  depends_on = [azurerm_virtual_machine_extension.avdvms_joindomain_adds_win11p]
}