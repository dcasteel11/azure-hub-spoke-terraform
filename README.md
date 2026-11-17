# azure-hub-spoke-terraform

A Terraform module that builds an Azure hub-and-spoke network: one hub virtual network for shared services, any number of workload spokes, two-way peering, a network security group on every workload subnet, and optional forced tunneling of spoke traffic through a hub firewall or NVA.

## Why hub-and-spoke

Centralizing egress, inspection and shared services in a hub keeps security controls in one place, while each workload team gets its own spoke that can be scoped to its own subscription, RBAC and policy. Adding a workload becomes a data change (a new entry in `spokes`), not new network design.

## What it creates

| Resource | Count |
|---|---|
| Resource group, VNet | 1 hub + 1 per spoke |
| Subnets | As defined in `hub_subnets` and each spoke's `subnets` |
| NSGs | 1 per spoke subnet and per non-reserved hub subnet |
| Route tables | 1 per spoke, only when `hub_firewall_private_ip` is set |
| VNet peerings | 2 per spoke (hub to spoke, spoke to hub) |

Reserved subnet names (`AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet` and others) are created in the hub without an NSG, as Azure requires.

## Usage

```hcl
module "network" {
  source = "github.com/dcasteel11/azure-hub-spoke-terraform"

  location    = "eastus2"
  name_prefix = "contoso-prd"

  hub_address_space = ["10.0.0.0/22"]

  hub_subnets = {
    AzureFirewallSubnet = { address_prefixes = ["10.0.0.0/26"] }
    shared-services     = { address_prefixes = ["10.0.1.0/24"] }
  }

  hub_firewall_private_ip = "10.0.0.4"

  spokes = {
    app = {
      address_space = ["10.1.0.0/22"]
      subnets = {
        web = { address_prefixes = ["10.1.0.0/24"] }
      }
    }
  }
}
```

A complete example is in [`examples/basic`](examples/basic).

## Inputs

| Name | Description | Default |
|---|---|---|
| `location` | Azure region | required |
| `name_prefix` | Prefix for resource names (3-20 lowercase characters) | required |
| `hub_address_space` | Hub VNet address space | required |
| `hub_subnets` | Hub subnets keyed by name | required |
| `spokes` | Spoke VNets and their subnets, keyed by workload name | `{}` |
| `hub_firewall_private_ip` | Firewall or NVA IP; adds a 0.0.0.0/0 route on spoke subnets | `null` |
| `use_remote_gateways` | Let spokes use a VPN or ExpressRoute gateway in the hub | `false` |
| `tags` | Tags for every resource | `{}` |

## Outputs

`hub_vnet_id`, `hub_subnet_ids`, `spoke_vnet_ids`, `spoke_subnet_ids`, `spoke_nsg_ids`. Subnet and NSG maps are keyed by `spoke/subnet` so other modules (private endpoints, AKS, App Service integration) can look them up directly.

## CI

Every push and pull request runs `terraform fmt`, `terraform validate` on the module and example, TFLint, and a Checkov security scan. See [`.github/workflows/terraform-ci.yml`](.github/workflows/terraform-ci.yml).

## Design notes

NSGs are created empty on purpose. Rules belong to the workload that owns the subnet and can be attached from outside the module using `spoke_nsg_ids`, which keeps network ownership and application ownership separate.

Requires Terraform 1.5 or later and the AzureRM provider 4.x.
