resource "azurerm_resource_group" "rg_primary" {
  name     = "${var.resource_prefix}-${var.primary_location}-rg"
  location = var.primary_location
}

resource "azurerm_resource_group" "rg_secondary" {
  name     = "${var.resource_prefix}-${var.secondary_location}-rg"
  location = var.secondary_location
}

resource "azurerm_windows_virtual_machine" "domain_controller" {
  name                     = "${var.resource_prefix}-adds-dc1"
  resource_group_name      = azurerm_resource_group.rg_primary.name
  location                 = var.primary_location
  network_interface_ids    = [azurerm_network_interface.dc_nic.id]
  size                     = var.dcsize
  computer_name            = "${var.resource_prefix}-adds-dc1"
  admin_username           = var.admin_username
  admin_password           = local.local_password
  license_type             = "Windows_Server"
  provision_vm_agent       = true
  enable_automatic_updates = false
  patch_mode               = "Manual"

  boot_diagnostics {
    storage_account_uri = ""
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "20348.887.220806"
  }

  os_disk {
    name                 = "${var.resource_prefix}-dc1-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_virtual_machine_extension" "dsc_domain" {
  name                       = "createrootdomain"
  virtual_machine_id         = azurerm_windows_virtual_machine.domain_controller.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.80"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_windows_virtual_machine.domain_controller, azurerm_storage_blob.dsc_files]

  settings = <<SETTINGS
    {
      "modulesUrl": "${local.dsc_endpoint}",
      "configurationFunction": "CreateRootDomain.ps1\\CreateRootDomain",
      "properties": {
        "AdminCreds": {
            "UserName": "${var.admin_username}",
            "Password": "PrivateSettingsRef:AdminPassword"
        },
        "DomainParameters": [
            {
                "DomainName": "${var.domain_name}",
                "AADDomainName": "${var.tenant_name}"
            }
        ]        
      }
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Items": {
                  "AdminPassword": "${local.local_password}"
               }
    }
  PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "creategpos_aad_connect" {
  name                       = "domaingpos_aadconnect"
  virtual_machine_id         = azurerm_windows_virtual_machine.domain_controller.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.dsc_domain, azurerm_storage_blob.script_files_creategpos_aad_connect]

  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell.exe -Command \"./CreateGPOsInstallAADConnect.ps1 -DomainName ${var.domain_name} -DCName ${azurerm_windows_virtual_machine.domain_controller.name} -StorageAccountName ${azurerm_storage_account.storage_account_adds.name} -ShareName ${local.profile_share_name} -DscStorageAccountName ${azurerm_storage_account.dsc_storage_account.name} -LocalUsername ${var.admin_username} -LocalPasswd ${local.local_password} -TenantName ${var.tenant_name} -CloudAdmin ${var.cloud_admin} -CloudAdminPasswd ${local.local_cloudadmin_password};\""
    }
  PROTECTED_SETTINGS

  settings = <<SETTINGS
    {
        "fileUris": [
          "${local.creategposaadconnect_script}"
        ]
    }
  SETTINGS
}

resource "azurerm_shared_image_gallery" "compute_gallery" {
  name                = "${var.resource_prefix}gallery"
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location
  description         = "Shared images"

  tags = {
    Environment = "Lab"
    Tech        = "Terraform"
  }
}

resource "azurerm_windows_virtual_machine" "win10_template" {
  name                     = "${var.resource_prefix}-tempvm1"
  resource_group_name      = azurerm_resource_group.rg_primary.name
  location                 = var.primary_location
  network_interface_ids    = [azurerm_network_interface.tempvm1_nic.id]
  size                     = var.vmsize
  computer_name            = "${var.resource_prefix}tempvm1"
  admin_username           = var.admin_username
  admin_password           = local.local_password
  license_type             = "Windows_Client"
  provision_vm_agent       = true
  enable_automatic_updates = false
  patch_mode               = "Manual"

  boot_diagnostics {
    storage_account_uri = ""
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "win10-22h2-avd-m365-g2"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.resource_prefix}-tempvm1-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_virtual_machine_extension" "sysprep_tempvm" {
  name                       = "sysprep_tempvm"
  virtual_machine_id         = azurerm_windows_virtual_machine.win10_template.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_windows_virtual_machine.win10_template]

  protected_settings = <<PROTECTED_SETTINGS
  {    
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted C:\\windows\\system32\\sysprep\\sysprep.exe /generalize /oobe /shutdown /mode:vm"
  }
  PROTECTED_SETTINGS
}

resource "null_resource" "generalize_tempvm" {
  depends_on = [azurerm_virtual_machine_extension.sysprep_tempvm]
  provisioner "local-exec" {
    command = "az vm generalize --resource-group ${azurerm_resource_group.rg_primary.name} --name ${azurerm_windows_virtual_machine.win10_template.name}"
  }
}

resource "time_sleep" "wait_generalize" {
  depends_on      = [null_resource.generalize_tempvm]
  count           = 60
  create_duration = "1s"
}

resource "null_resource" "deallocate_tempvm" {
  depends_on = [time_sleep.wait_generalize]
  provisioner "local-exec" {
    command = "az vm deallocate --resource-group ${azurerm_resource_group.rg_primary.name} --name ${azurerm_windows_virtual_machine.win10_template.name}"
  }
}

resource "azurerm_shared_image" "win10_multi" {
  name                = "win10-avd-image-multi"
  gallery_name        = azurerm_shared_image_gallery.compute_gallery.name
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location
  os_type             = "Windows"
  hyper_v_generation  = "V2"

  identifier {
    publisher = "AVDLabs"
    offer     = "office-365-multi"
    sku       = "win10-22h2-avd-m365-g2"
  }
}

resource "azurerm_image" "win10_image" {
  name                      = "win10-multi-image"
  location                  = var.primary_location
  resource_group_name       = azurerm_resource_group.rg_primary.name
  source_virtual_machine_id = azurerm_windows_virtual_machine.win10_template.id
  hyper_v_generation        = "V2"
  depends_on                = [null_resource.generalize_tempvm]
}

resource "azurerm_shared_image_version" "compute_gallery_version" {
  name                = "0.0.1"
  gallery_name        = azurerm_shared_image_gallery.compute_gallery.name
  image_name          = azurerm_shared_image.win10_multi.name
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location
  managed_image_id    = azurerm_image.win10_image.id

  target_region {
    name                   = var.primary_location
    regional_replica_count = 1
    storage_account_type   = "Standard_LRS"
  }

  target_region {
    name                   = var.secondary_location
    regional_replica_count = 1
    storage_account_type   = "Standard_LRS"
  }
}

#Windows 11
resource "azurerm_windows_virtual_machine" "win11_template" {
  count                    = var.deploy_personal
  name                     = "${var.resource_prefix}-tempvm2"
  resource_group_name      = azurerm_resource_group.rg_primary.name
  location                 = var.primary_location
  network_interface_ids    = [azurerm_network_interface.tempvm2_nic[0].id]
  size                     = var.vmsize
  computer_name            = "${var.resource_prefix}-tempvm2"
  admin_username           = var.admin_username
  admin_password           = local.local_password
  license_type             = "Windows_Client"
  provision_vm_agent       = true
  enable_automatic_updates = false
  patch_mode               = "Manual"

  boot_diagnostics {
    storage_account_uri = ""
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-ent"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.resource_prefix}-tempvm2-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_virtual_machine_extension" "sysprep_win11_tempvm" {
  count                      = var.deploy_personal
  name                       = "sysprep_tempvm"
  virtual_machine_id         = azurerm_windows_virtual_machine.win11_template[0].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.9"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_windows_virtual_machine.win11_template[0]]

  protected_settings = <<PROTECTED_SETTINGS
  {    
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted C:\\windows\\system32\\sysprep\\sysprep.exe /generalize /oobe /shutdown /mode:vm"
  }
  PROTECTED_SETTINGS
}

resource "null_resource" "generalize_win11_tempvm" {
  count      = var.deploy_personal
  depends_on = [azurerm_virtual_machine_extension.sysprep_win11_tempvm[0]]
  provisioner "local-exec" {
    command = "az vm generalize --resource-group ${azurerm_resource_group.rg_primary.name} --name ${azurerm_windows_virtual_machine.win11_template[0].name}"
  }
}

resource "time_sleep" "wait_generalize_win11" {
  depends_on      = [null_resource.generalize_win11_tempvm[0]]
  count           = 60
  create_duration = "1s"
}

resource "null_resource" "deallocate_win11_tempvm" {
  count = var.deploy_personal
  depends_on = [time_sleep.wait_generalize_win11[0], null_resource.generalize_win11_tempvm[0]]
  provisioner "local-exec" {
    command = "az vm deallocate --resource-group ${azurerm_resource_group.rg_primary.name} --name ${azurerm_windows_virtual_machine.win11_template[0].name}"
  }
}

resource "azurerm_shared_image" "win11_single" {
  count               = var.deploy_personal
  name                = "win11-avd-image-single"
  gallery_name        = azurerm_shared_image_gallery.compute_gallery.name
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location
  os_type             = "Windows"
  hyper_v_generation  = "V2"

  identifier {
    publisher = "AVDLabs"
    offer     = "windows-11"
    sku       = "win11-22h2-ent"
  }
}

resource "azurerm_image" "win11_image" {
  count                     = var.deploy_personal
  name                      = "win11-single-image"
  location                  = var.primary_location
  resource_group_name       = azurerm_resource_group.rg_primary.name
  hyper_v_generation        = "V2"
  source_virtual_machine_id = azurerm_windows_virtual_machine.win11_template[0].id
  depends_on                = [null_resource.generalize_win11_tempvm]
}

resource "azurerm_shared_image_version" "compute_gallery_version_win11p" {
  count               = var.deploy_personal
  name                = "0.0.1"
  gallery_name        = azurerm_shared_image_gallery.compute_gallery.name
  image_name          = azurerm_shared_image.win11_single[0].name
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location
  managed_image_id    = azurerm_image.win11_image[0].id

  target_region {
    name                   = var.primary_location
    regional_replica_count = 1
    storage_account_type   = "Standard_LRS"
  }
}