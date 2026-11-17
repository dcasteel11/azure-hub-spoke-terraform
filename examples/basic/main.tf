terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "network" {
  source = "../.."

  location    = "eastus2"
  name_prefix = "demo-dev"

  hub_address_space = ["10.0.0.0/22"]

  hub_subnets = {
    AzureFirewallSubnet = { address_prefixes = ["10.0.0.0/26"] }
    GatewaySubnet       = { address_prefixes = ["10.0.0.64/27"] }
    shared-services     = { address_prefixes = ["10.0.1.0/24"] }
  }

  # Spoke egress is routed through the hub firewall at this address.
  hub_firewall_private_ip = "10.0.0.4"

  spokes = {
    app = {
      address_space = ["10.1.0.0/22"]
      subnets       = {
        web = { address_prefixes = ["10.1.0.0/24"] }

        data = {
          address_prefixes                  = ["10.1.1.0/24"]
          private_endpoint_network_policies = "Enabled"
        }
      }
    }
    data = {
      address_space = ["10.2.0.0/22"]
      subnets       = {
        private-endpoints = { address_prefixes = ["10.2.0.0/24"] }
      }
    }
  }

  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

output "spoke_subnet_ids" {
  value = module.network.spoke_subnet_ids
}
