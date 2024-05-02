resource "azurerm_virtual_network" "vnet_primary" {
  name                = "${var.resource_prefix}-${var.primary_location}-vnet"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name
  address_space       = [var.primary_vnet_address_space]
}

resource "azurerm_subnet" "private_subnets_primary" {
  count                                         = local.priv_subnet_count
  name                                          = "subnet${count.index + 1}"
  address_prefixes                              = [local.private_subnets_primary[count.index]]
  resource_group_name                           = azurerm_resource_group.rg_primary.name
  virtual_network_name                          = azurerm_virtual_network.vnet_primary.name
  private_link_service_network_policies_enabled = false
}

resource "azurerm_virtual_network" "vnet_secondary" {
  name                = "${var.resource_prefix}-${var.secondary_location}-vnet"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name
  address_space       = [var.secondary_vnet_address_space]
}

resource "azurerm_subnet" "private_subnets_secondary" {
  count                                         = local.priv_subnet_count
  name                                          = "subnet${count.index + 1}"
  address_prefixes                              = [local.private_subnets_secondary[count.index]]
  resource_group_name                           = azurerm_resource_group.rg_secondary.name
  virtual_network_name                          = azurerm_virtual_network.vnet_secondary.name
  private_link_service_network_policies_enabled = false
}

resource "azurerm_network_security_group" "avd_nsg_primary" {
  name                = "${var.resource_prefix}-${var.primary_location}-nsg"
  location            = var.primary_location
  resource_group_name = azurerm_resource_group.rg_primary.name
}

resource "azurerm_subnet_network_security_group_association" "private_subnets_primary_nsg" {
  count                     = local.priv_subnet_count
  network_security_group_id = azurerm_network_security_group.avd_nsg_primary.id
  subnet_id                 = azurerm_subnet.private_subnets_primary[count.index].id
}

resource "azurerm_network_security_rule" "allow_rdp" {
  name                        = "Allow_RDP"
  resource_group_name         = azurerm_resource_group.rg_primary.name
  access                      = "Allow"
  direction                   = "Inbound"
  source_address_prefix       = data.http.my_ip.response_body
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["3389"]
  network_security_group_name = azurerm_network_security_group.avd_nsg_primary.name
  priority                    = 100
  protocol                    = "Tcp"
}

resource "azurerm_network_security_rule" "allow_rdp_shorpath" {
  name                        = "Allow_RDP_Shortpath"
  resource_group_name         = azurerm_resource_group.rg_primary.name
  access                      = "Allow"
  direction                   = "Inbound"
  source_address_prefix       = data.http.my_ip.response_body
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["3390"]
  network_security_group_name = azurerm_network_security_group.avd_nsg_primary.name
  priority                    = 110
  protocol                    = "Udp"
}

resource "azurerm_network_security_group" "avd_nsg_secondary" {
  name                = "${var.resource_prefix}-${var.secondary_location}-nsg"
  location            = var.secondary_location
  resource_group_name = azurerm_resource_group.rg_secondary.name
}

resource "azurerm_subnet_network_security_group_association" "private_subnets_secondary_nsg" {
  count                     = local.priv_subnet_count
  network_security_group_id = azurerm_network_security_group.avd_nsg_secondary.id
  subnet_id                 = azurerm_subnet.private_subnets_secondary[count.index].id
}

resource "azurerm_network_security_rule" "allow_rdp_sec" {
  name                        = "Allow_RDP"
  resource_group_name         = azurerm_resource_group.rg_secondary.name
  access                      = "Allow"
  direction                   = "Inbound"
  source_address_prefix       = data.http.my_ip.response_body
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["3389"]
  network_security_group_name = azurerm_network_security_group.avd_nsg_secondary.name
  priority                    = 100
  protocol                    = "Tcp"
}

resource "azurerm_network_security_rule" "allow_rdp_shorpath_sec" {
  name                        = "Allow_RDP_Shortpath"
  resource_group_name         = azurerm_resource_group.rg_secondary.name
  access                      = "Allow"
  direction                   = "Inbound"
  source_address_prefix       = data.http.my_ip.response_body
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["3390"]
  network_security_group_name = azurerm_network_security_group.avd_nsg_secondary.name
  priority                    = 110
  protocol                    = "Udp"
}

resource "azurerm_virtual_network_peering" "primary_secondary_peering" {
  name                      = "primary_secondary_peering"
  resource_group_name       = azurerm_resource_group.rg_primary.name
  virtual_network_name      = azurerm_virtual_network.vnet_primary.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_secondary.id
}

resource "azurerm_virtual_network_peering" "secondary_primary_peering" {
  name                      = "secondary_primary_peering"
  resource_group_name       = azurerm_resource_group.rg_secondary.name
  virtual_network_name      = azurerm_virtual_network.vnet_secondary.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_primary.id
}

resource "azurerm_public_ip" "dc_public_ip" {
  name                = "${var.resource_prefix}-dc1-pip1"
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "dc_nic" {
  name                = "${var.resource_prefix}-dc1-nic1"
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.private_subnets_primary[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dc_public_ip.id
  }
}

resource "azurerm_virtual_network_dns_servers" "dnsserver_dc_primary" {
  virtual_network_id = azurerm_virtual_network.vnet_primary.id
  dns_servers        = [azurerm_network_interface.dc_nic.private_ip_address]
  depends_on         = [azurerm_virtual_machine_extension.dsc_domain]
}

resource "azurerm_virtual_network_dns_servers" "dnsserver_dc_secondary" {
  virtual_network_id = azurerm_virtual_network.vnet_secondary.id
  dns_servers        = [azurerm_network_interface.dc_nic.private_ip_address]
  depends_on         = [azurerm_virtual_machine_extension.dsc_domain]
}

resource "azurerm_network_interface" "tempvm1_nic" {
  name                = "${var.resource_prefix}-tempvm1-nic1"
  resource_group_name = azurerm_resource_group.rg_temp.name
  location            = var.primary_location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.private_subnets_primary[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "tempvm2_nic" {
  count               = var.deploy_personal
  name                = "${var.resource_prefix}-tempvm2-nic1"
  resource_group_name = azurerm_resource_group.rg_temp.name
  location            = var.primary_location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.private_subnets_primary[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "avdvmnic_adds" {
  count               = var.vmcount
  name                = "${var.resource_prefix}-nic-adds${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.private_subnets_primary[1].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "avdvmnic_haadj" {
  count               = var.deploy_hybrid
  name                = "${var.resource_prefix}-nic-haadj${count.index}"
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.private_subnets_primary[1].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "avdvmnic_aad" {
  count               = var.vmcount
  name                = "${var.resource_prefix}-nic-aad${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg_secondary.name
  location            = var.secondary_location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.private_subnets_secondary[1].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "avdvmnic_adds_win11p" {
  count               = var.deploy_personal
  name                = "${var.resource_prefix}-nic-adds-w11p${count.index}"
  resource_group_name = azurerm_resource_group.rg_primary.name
  location            = var.primary_location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.private_subnets_primary[1].id
    private_ip_address_allocation = "Dynamic"
  }
}

#Private DNS Zone privatelink.file.core.windows.net

resource "azurerm_private_dns_zone" "privatedns_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg_primary.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_primary_link" {
  name                  = "dns-vnet-primary-link"
  resource_group_name   = azurerm_resource_group.rg_primary.name
  private_dns_zone_name = azurerm_private_dns_zone.privatedns_file.name
  virtual_network_id    = azurerm_virtual_network.vnet_primary.id
}

#Private DNS Zone privatelink.wvd.microsoft.com

resource "azurerm_private_dns_zone" "privatedns_avd" {
  name                = "privatelink.wvd.microsoft.com"
  resource_group_name = azurerm_resource_group.rg_primary.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_primary_link_avd" {
  name                  = "dns-vnet-primary-link"
  resource_group_name   = azurerm_resource_group.rg_primary.name
  private_dns_zone_name = azurerm_private_dns_zone.privatedns_avd.name
  virtual_network_id    = azurerm_virtual_network.vnet_primary.id
}

#Private DNS Zone privatelink-global.wvd.microsoft.com

resource "azurerm_private_dns_zone" "privatedns_avd_global" {
  name                = "privatelink-global.wvd.microsoft.com"
  resource_group_name = azurerm_resource_group.rg_primary.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_primary_link_avd_global" {
  name                  = "dns-vnet-primary-link"
  resource_group_name   = azurerm_resource_group.rg_primary.name
  private_dns_zone_name = azurerm_private_dns_zone.privatedns_avd_global.name
  virtual_network_id    = azurerm_virtual_network.vnet_primary.id
}