variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "name_prefix" {
  description = "Short prefix used in resource names, e.g. \"contoso-prd\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.name_prefix))
    error_message = "name_prefix must be 3-20 lowercase letters, numbers or hyphens."
  }
}

variable "hub_address_space" {
  description = "Address space for the hub virtual network."
  type        = list(string)
}

variable "hub_subnets" {
  description = "Subnets in the hub. Reserved names such as AzureFirewallSubnet and GatewaySubnet are supported and do not get an NSG."
  type        = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
  }))
}

variable "spokes" {
  description = "Spoke virtual networks keyed by workload name."
  type        = map(object({
    address_space = list(string)
    subnets       = map(object({
      address_prefixes                  = list(string)
      service_endpoints                 = optional(list(string), [])
      private_endpoint_network_policies = optional(string, "Enabled")
    }))
  }))
  default = {}
}

variable "hub_firewall_private_ip" {
  description = "Private IP of the hub firewall or NVA. When set, spoke subnets get a default route through it."
  type        = string
  default     = null
}

variable "use_remote_gateways" {
  description = "Set true when the hub has a VPN or ExpressRoute gateway that spokes should use."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
