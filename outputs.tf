output "hub_vnet_id" {
  description = "ID of the hub virtual network."
  value       = azurerm_virtual_network.hub.id
}

output "hub_subnet_ids" {
  description = "Hub subnet IDs keyed by subnet name."
  value       = { for k, s in azurerm_subnet.hub : k => s.id }
}

output "spoke_vnet_ids" {
  description = "Spoke virtual network IDs keyed by spoke name."
  value       = { for k, v in azurerm_virtual_network.spoke : k => v.id }
}

output "spoke_subnet_ids" {
  description = "Spoke subnet IDs keyed by \"spoke/subnet\"."
  value       = { for k, s in azurerm_subnet.spoke : k => s.id }
}

output "spoke_nsg_ids" {
  description = "Spoke NSG IDs keyed by \"spoke/subnet\", for attaching rules outside the module."
  value       = { for k, n in azurerm_network_security_group.spoke : k => n.id }
}
