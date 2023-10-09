resource "azuread_group" "cloud_avdadmins" {
  display_name     = "Cloud_AVD_Admins"
  description      = "Cloud AVD Admins"
  security_enabled = true
}

resource "azuread_group" "cloud_avdusers" {
  display_name     = "Cloud_AVD_Users"
  description      = "Cloud AVD Users"
  security_enabled = true
}

resource "azuread_group" "cloud_avdcomputers" {
  display_name     = "Cloud_AVD_Computers"
  description      = "Cloud AVD Computers"
  security_enabled = true
}

resource "azurerm_role_assignment" "avd_desktop_poweronoff_assignment" {
  scope                            = data.azurerm_subscription.subscription_id.id
  role_definition_name             = "Desktop Virtualization Power On Off Contributor"
  principal_id                     = data.azuread_service_principal.avd_principal.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_avdtfappgroup_adds" {
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_adds.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_avdtfappgroup_adds_apps" {
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_adds_apps.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_avdtfappgroup_aad" {
  count                = var.deploy_aad
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_aad[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_avdtfappgroup_adds_win11p" {
  count                = var.deploy_personal
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_adds_win11p[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_avdtfappgroup_haadj" {
  count                = var.deploy_hybrid
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_haadj[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_avdtfappgroup_adds" {
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_adds.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_avdtfappgroup_adds_apps" {
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_adds_apps.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_avdtfappgroup_aad" {
  count                = var.deploy_aad
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_aad[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_avdtfappgroup_adds_win11p" {
  count                = var.deploy_personal
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_adds_win11p[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_avdtfappgroup_haadj" {
  count                = var.deploy_hybrid
  scope                = azurerm_virtual_desktop_application_group.avdtfappgroup_haadj[0].id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_vm" {
  scope                = azurerm_resource_group.rg_primary.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_vm" {
  scope                = azurerm_resource_group.rg_primary.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_vm_secondary" {
  scope                = azurerm_resource_group.rg_secondary.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_vm_secondary" {
  scope                = azurerm_resource_group.rg_secondary.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_share_adds" {
  scope                = azurerm_storage_account.storage_account_adds.id
  role_definition_name = "Storage File Data SMB Share Elevated Contributor"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_share_adds" {
  scope                = azurerm_storage_account.storage_account_adds.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_avdcomputers_share_adds" {
  scope                = azurerm_storage_account.storage_account_adds.id
  role_definition_name = "Storage File Data SMB Share Reader"
  principal_id         = azuread_group.cloud_avdcomputers.object_id
  depends_on           = [azuread_group.cloud_avdcomputers]
}

resource "azurerm_role_assignment" "role_assignment_avdadmins_share_aad" {
  scope                = azurerm_storage_account.storage_account_aad.id
  role_definition_name = "Storage File Data SMB Share Elevated Contributor"
  principal_id         = azuread_group.cloud_avdadmins.object_id
  depends_on           = [azuread_group.cloud_avdadmins]
}

resource "azurerm_role_assignment" "role_assignment_avdusers_share_aad" {
  scope                = azurerm_storage_account.storage_account_aad.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azuread_group.cloud_avdusers.object_id
  depends_on           = [azuread_group.cloud_avdusers]
}

resource "azurerm_role_assignment" "role_assignment_vmadds_contributor" {
  scope                = azurerm_resource_group.rg_primary.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_virtual_machine.avdvms_adds[0].identity[0].principal_id
  depends_on           = [azurerm_windows_virtual_machine.avdvms_adds[0]]
}

resource "azurerm_role_assignment" "role_assignment_vmadds_contributor_sec" {
  scope                = azurerm_resource_group.rg_secondary.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_virtual_machine.avdvms_adds[0].identity[0].principal_id
  depends_on           = [azurerm_windows_virtual_machine.avdvms_adds[0]]
}

resource "azuread_directory_role" "global_admin" {
  display_name = "Global Administrator"
}

resource "azuread_directory_role_assignment" "role_assignment_vmadds_sp_global_admin" {
  role_id             = azuread_directory_role.global_admin.template_id
  principal_object_id = azurerm_windows_virtual_machine.avdvms_adds[0].identity[0].principal_id
} 