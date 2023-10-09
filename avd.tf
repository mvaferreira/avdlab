##ADDS Pooled

resource "azurerm_virtual_desktop_host_pool" "avdtfpool_adds" {
  name                = "${var.resource_prefix}-adds-pooled"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name

  friendly_name            = "ADDS Pooled"
  validate_environment     = false
  description              = "ADDS Desktops Pooled"
  type                     = "Pooled"
  maximum_sessions_allowed = 3
  load_balancer_type       = "BreadthFirst"
  start_vm_on_connect      = true
  custom_rdp_properties    = "drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:0;"

  scheduled_agent_updates {
    enabled = true
    schedule {
      day_of_week = "Saturday"
      hour_of_day = 2
    }
  }
}

resource "azurerm_virtual_desktop_application_group" "avdtfappgroup_adds" {
  name                = "${var.resource_prefix}-appgrp-adds"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name

  type                         = "Desktop"
  host_pool_id                 = azurerm_virtual_desktop_host_pool.avdtfpool_adds.id
  friendly_name                = "ADDSDesktops"
  description                  = "ADDS Desktops Pooled"
  default_desktop_display_name = "ADDS Desktop"
}

resource "azurerm_virtual_desktop_application_group" "avdtfappgroup_adds_apps" {
  name                = "${var.resource_prefix}-appgrp-adds-apps"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name

  type          = "RemoteApp"
  host_pool_id  = azurerm_virtual_desktop_host_pool.avdtfpool_adds.id
  friendly_name = "CompanyApps"
  description   = "Company Apps"
}

resource "azurerm_virtual_desktop_application" "notepad_adds" {
  name                         = "Notepad"
  application_group_id         = azurerm_virtual_desktop_application_group.avdtfappgroup_adds_apps.id
  friendly_name                = "Notepad"
  description                  = "Notepad"
  path                         = "C:\\Windows\\system32\\notepad.exe"
  command_line_argument_policy = "DoNotAllow"
  show_in_portal               = true
  icon_path                    = "C:\\Windows\\system32\\notepad.exe"
  icon_index                   = 0
}

resource "azurerm_virtual_desktop_workspace" "avdwks_adds" {
  name                = "${var.resource_prefix}-adds-wks"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name

  friendly_name = "Active Directory - Pooled"
  description   = "ADDS Pooled"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_wks_app_group_adds" {
  workspace_id         = azurerm_virtual_desktop_workspace.avdwks_adds.id
  application_group_id = azurerm_virtual_desktop_application_group.avdtfappgroup_adds.id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_wks_app_group_adds_apps" {
  workspace_id         = azurerm_virtual_desktop_workspace.avdwks_adds.id
  application_group_id = azurerm_virtual_desktop_application_group.avdtfappgroup_adds_apps.id
}

##AAD Pooled

resource "azurerm_virtual_desktop_host_pool" "avdtfpool_aad" {
  count               = var.deploy_aad
  name                = "${var.resource_prefix}-aad-pooled"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name

  friendly_name            = "AAD Pooled"
  validate_environment     = false
  description              = "AAD Desktops Pooled"
  type                     = "Pooled"
  maximum_sessions_allowed = 3
  load_balancer_type       = "BreadthFirst"
  start_vm_on_connect      = true
  custom_rdp_properties    = "drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:0;enablerdsaadauth:i:1;"
}

resource "azurerm_virtual_desktop_application_group" "avdtfappgroup_aad" {
  count               = var.deploy_aad
  name                = "${var.resource_prefix}-appgrp-aad"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name

  type                         = "Desktop"
  host_pool_id                 = azurerm_virtual_desktop_host_pool.avdtfpool_aad[0].id
  friendly_name                = "AADDesktops"
  description                  = "AAD Desktops Pooled"
  default_desktop_display_name = "AAD Desktop"
}

resource "azurerm_virtual_desktop_workspace" "avdwks_aad" {
  count               = var.deploy_aad == 1 || var.deploy_hybrid == 1 ? 1 : 0
  name                = "${var.resource_prefix}-aad-wks"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name

  friendly_name = "Azure Active Directory - Pooled"
  description   = "AAD Pooled"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_wks_app_group_aad" {
  count                = var.deploy_aad
  workspace_id         = azurerm_virtual_desktop_workspace.avdwks_aad[0].id
  application_group_id = azurerm_virtual_desktop_application_group.avdtfappgroup_aad[0].id
}

##ADDS Personal

resource "azurerm_virtual_desktop_host_pool" "avdtfpool_adds_win11p" {
  count                            = var.deploy_personal
  name                             = "${var.resource_prefix}-adds-personal-${count.index}"
  location                         = var.primary_location
  resource_group_name              = azurerm_resource_group.rg_primary.name
  friendly_name                    = "ADDS Personal"
  validate_environment             = false
  description                      = "ADDS Desktops Personal"
  type                             = "Personal"
  personal_desktop_assignment_type = "Automatic"
  load_balancer_type               = "Persistent"
  start_vm_on_connect              = true
  custom_rdp_properties            = "drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:0;"
}

resource "azurerm_virtual_desktop_application_group" "avdtfappgroup_adds_win11p" {
  count               = var.deploy_personal
  name                = "${var.resource_prefix}-appgrp-adds-win11p-${count.index}"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name

  type                         = "Desktop"
  host_pool_id                 = azurerm_virtual_desktop_host_pool.avdtfpool_adds_win11p[0].id
  friendly_name                = "ADDSDesktops"
  description                  = "ADDS Desktops Personal"
  default_desktop_display_name = "ADDS Personal Desktop"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_wks_app_group_adds_win11p" {
  count                = var.deploy_personal
  workspace_id         = azurerm_virtual_desktop_workspace.avdwks_adds.id
  application_group_id = azurerm_virtual_desktop_application_group.avdtfappgroup_adds_win11p[0].id
}

##ADDS+AAD Hybrid Pooled
resource "azurerm_virtual_desktop_host_pool" "avdtfpool_haadj" {
  count               = var.deploy_hybrid
  name                = "${var.resource_prefix}-haadj-pooled"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name

  friendly_name            = "HAADJ Pooled"
  validate_environment     = false
  description              = "HAADJ Desktops Pooled"
  type                     = "Pooled"
  maximum_sessions_allowed = 3
  load_balancer_type       = "BreadthFirst"
  start_vm_on_connect      = true
  custom_rdp_properties    = "drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:0;enablerdsaadauth:i:1;"
}

resource "azurerm_virtual_desktop_application_group" "avdtfappgroup_haadj" {
  count               = var.deploy_hybrid
  name                = "${var.resource_prefix}-appgrp-haadj"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name

  type                         = "Desktop"
  host_pool_id                 = azurerm_virtual_desktop_host_pool.avdtfpool_haadj[0].id
  friendly_name                = "HAADJDesktops"
  description                  = "HAADJ Desktops Pooled"
  default_desktop_display_name = "HAADJ Desktop"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_wks_app_group_haadj" {
  count                = var.deploy_hybrid
  workspace_id         = azurerm_virtual_desktop_workspace.avdwks_aad[0].id
  application_group_id = azurerm_virtual_desktop_application_group.avdtfappgroup_haadj[0].id
}

#Scaling Plan
resource "azurerm_virtual_desktop_scaling_plan" "scaling_plan_adds" {
  name                = "${var.resource_prefix}-scaling-plan"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name
  friendly_name       = "Scaling Plan Example"
  description         = "Example Scaling Plan"
  time_zone           = "GMT Standard Time"

  schedule {
    name                                 = "Weekdays"
    days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    ramp_up_start_time                   = "07:00"
    ramp_up_load_balancing_algorithm     = "BreadthFirst"
    ramp_up_minimum_hosts_percent        = 20
    ramp_up_capacity_threshold_percent   = 10
    peak_start_time                      = "09:00"
    peak_load_balancing_algorithm        = "BreadthFirst"
    ramp_down_start_time                 = "18:00"
    ramp_down_load_balancing_algorithm   = "DepthFirst"
    ramp_down_minimum_hosts_percent      = 10
    ramp_down_force_logoff_users         = false
    ramp_down_wait_time_minutes          = 45
    ramp_down_notification_message       = "Please log off in the next 45 minutes..."
    ramp_down_capacity_threshold_percent = 5
    ramp_down_stop_hosts_when            = "ZeroSessions"
    off_peak_start_time                  = "20:00"
    off_peak_load_balancing_algorithm    = "DepthFirst"
  }

  host_pool {
    hostpool_id          = azurerm_virtual_desktop_host_pool.avdtfpool_adds.id
    scaling_plan_enabled = false
  }
}