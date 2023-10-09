data "template_file" "calculate_priv_subnets_primary" {
  count    = local.priv_subnet_count
  template = "$${cidrsubnet(starting_address_space,8,number_subnets)}"

  vars = {
    starting_address_space = var.primary_vnet_address_space
    number_subnets         = count.index
  }
}

data "template_file" "calculate_priv_subnets_secondary" {
  count    = local.priv_subnet_count
  template = "$${cidrsubnet(starting_address_space,8,number_subnets)}"

  vars = {
    starting_address_space = var.secondary_vnet_address_space
    number_subnets         = count.index
  }
}

data "azurerm_subscription" "subscription_id" {
  subscription_id = var.subscription_id
}

data "azuread_service_principal" "avd_principal" {
  display_name = "Azure Virtual Desktop"
}

data "http" "my_ip" {
  url = "http://ifconfig.me"
}

output "myip" {
  value = data.http.my_ip.response_body
}