locals {
  reserved_subnets = ["AzureFirewallSubnet", "AzureFirewallManagementSubnet", "GatewaySubnet", "AzureBastionSubnet", "RouteServerSubnet"]

  hub_nsg_subnets = {
    for name, s in var.hub_subnets : name => s
    if !contains(local.reserved_subnets, name)
  }

  # Flatten spokes -> subnets so each subnet is addressable by "spoke/subnet".
  spoke_subnets = merge([
    for spoke_name, spoke in var.spokes : {
      for subnet_name, subnet in spoke.subnets :
      "${spoke_name}/${subnet_name}" => merge(subnet, {
        spoke_name  = spoke_name
        subnet_name = subnet_name
      })
    }
  ]...)
}

# ---------------------------------------------------------------- Hub

resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.name_prefix}-hub"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.hub_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "hub" {
  #checkov:skip=CKV2_AZURE_31:Reserved subnets (firewall, gateway, Bastion) cannot take an NSG; all others are associated below
  for_each = var.hub_subnets

  name                 = each.key
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints
}

resource "azurerm_network_security_group" "hub" {
  for_each = local.hub_nsg_subnets

  name                = "nsg-${var.name_prefix}-hub-${lower(each.key)}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "hub" {
  for_each = local.hub_nsg_subnets

  subnet_id                 = azurerm_subnet.hub[each.key].id
  network_security_group_id = azurerm_network_security_group.hub[each.key].id
}

# ---------------------------------------------------------------- Spokes

resource "azurerm_resource_group" "spoke" {
  for_each = var.spokes

  name     = "rg-${var.name_prefix}-${each.key}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "vnet-${var.name_prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  address_space       = each.value.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "spoke" {
  for_each = local.spoke_subnets

  name                              = each.value.subnet_name
  resource_group_name               = azurerm_resource_group.spoke[each.value.spoke_name].name
  virtual_network_name              = azurerm_virtual_network.spoke[each.value.spoke_name].name
  address_prefixes                  = each.value.address_prefixes
  service_endpoints                 = each.value.service_endpoints
  private_endpoint_network_policies = each.value.private_endpoint_network_policies
}

# Every spoke subnet gets its own NSG so traffic rules can be scoped per tier.
resource "azurerm_network_security_group" "spoke" {
  for_each = local.spoke_subnets

  name                = "nsg-${var.name_prefix}-${each.value.spoke_name}-${lower(each.value.subnet_name)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.value.spoke_name].name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.spoke_subnets

  subnet_id                 = azurerm_subnet.spoke[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

# ---------------------------------------------------------------- Routing

# Force spoke egress through the hub firewall when one is provided.
resource "azurerm_route_table" "spoke" {
  for_each = var.hub_firewall_private_ip == null ? {} : var.spokes

  name                = "rt-${var.name_prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  tags                = var.tags

  route {
    name                   = "default-via-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub_firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = var.hub_firewall_private_ip == null ? {} : local.spoke_subnets

  subnet_id      = azurerm_subnet.spoke[each.key].id
  route_table_id = azurerm_route_table.spoke[each.value.spoke_name].id
}

# ---------------------------------------------------------------- Peering

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.spoke[each.key].name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = var.use_remote_gateways

  depends_on = [azurerm_virtual_network_peering.hub_to_spoke]
}
