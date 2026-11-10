<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11, < 2.0 |
| azapi | >= 2.4, < 3.0 |
| azurerm | >= 4.0, < 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azapi | >= 2.4, < 3.0 |
| azurerm | >= 4.0, < 5.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| bastion | git::https://github.com/Azure/terraform-azurerm-avm-res-network-bastionhost.git | 7c7d294caf81377671b99687aa75726e1072002e |
| dns\_resolver | git::https://github.com/Azure/terraform-azurerm-avm-res-network-dnsresolver.git | 73b1df385505485dee12fc3901756d4994fe9cc8 |
| hub | git::https://github.com/Azure/terraform-azurerm-avm-ptn-hubnetworking.git | 9c3096808897103cbea7aa3c37e64e9a1fe26a49 |

## Resources

| Name | Type |
| ---- | ---- |
| [azapi_resource.private_dns_link](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azurerm_firewall_policy_rule_collection_group.aks_egress](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) | resource |
| [azurerm_firewall_policy_rule_collection_group.transit](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) | resource |
| [azurerm_resource_group.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_virtual_network_peering.from_remote_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.to_remote_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| address\_space | Address space of the hub virtual network (a /22 is plenty). | `list(string)` | n/a | yes |
| environment | Environment name (e.g. dev, prod). Used in resource names. | `string` | n/a | yes |
| location | Azure region for the hub resources. | `string` | n/a | yes |
| region\_short | Short region code used in resource names (e.g. wus3, eus2). | `string` | n/a | yes |
| aks\_egress\_via\_firewall | Add the AKS required-egress rule collection (FQDN tag AzureKubernetesService, tunnel/NTP network rules, registries) to the firewall policy. Needed when this environment's stamps use outbound\_type = userDefinedRouting. No effect without enable\_firewall. | `bool` | `false` | no |
| bastion\_sku | Bastion SKU: Developer (free, no dedicated subnet, limited regions), Basic, Standard or Premium. | `string` | `"Basic"` | no |
| bastion\_subnet\_prefix | CIDR for AzureBastionSubnet (min /26). Defaults to .0.192/26 of the hub range. | `string` | `null` | no |
| dns\_inbound\_subnet\_prefix | CIDR for the resolver inbound endpoint subnet (min /28). Defaults to .0.128/28 of the hub range. | `string` | `null` | no |
| enable\_bastion | Deploy Azure Bastion in the hub for reaching private clusters/jumpboxes. Basic ~$140/mo; Developer is free but region-limited and has no SKU features. | `bool` | `false` | no |
| enable\_dns\_resolver | Deploy an Azure DNS Private Resolver with an inbound endpoint in the hub (~$180/mo per hub) so on-prem/VPN clients can resolve the environment's private DNS zone. Not needed for stamp-to-stamp resolution inside Azure. | `bool` | `false` | no |
| enable\_firewall | Deploy an Azure Firewall in the hub. Disabled by default: even the Basic SKU<br/>costs ~$300/month. When disabled the hub is just a peered virtual network,<br/>and spokes egress directly through their AKS load balancer. | `bool` | `false` | no |
| enable\_telemetry | Enable AVM module telemetry. Off by default to avoid any phone-home from this example. | `bool` | `false` | no |
| firewall\_management\_subnet\_prefix | CIDR for AzureFirewallManagementSubnet (required by the Basic SKU). Defaults to the second /26 of the hub address space. | `string` | `null` | no |
| firewall\_route\_entries | Extra routes for the firewall subnet's route table. Used for hub-to-hub<br/>transit: point each remote spoke CIDR at the remote hub's firewall private IP. | <pre>set(object({<br/>    name                = string<br/>    address_prefix      = string<br/>    next_hop_ip_address = string<br/>  }))</pre> | `[]` | no |
| firewall\_sku\_tier | Azure Firewall SKU tier when enable\_firewall is true. Basic is the cheapest (~$300/mo vs ~$900/mo for Standard). | `string` | `"Basic"` | no |
| firewall\_subnet\_prefix | CIDR for AzureFirewallSubnet. Defaults to the first /26 of the hub address space. | `string` | `null` | no |
| peer\_hub | Optional global VNet peering to another hub (both directions are created, so<br/>define this on exactly ONE of the two hubs). Peering alone does not make<br/>spoke-to-spoke traffic flow - that also needs firewalls and UDRs; see<br/>docs/architecture.md. | <pre>object({<br/>    vnet_id             = string<br/>    vnet_name           = string<br/>    resource_group_name = string<br/>  })</pre> | `null` | no |
| private\_dns\_zone\_id | Resource ID of the environment's central private DNS zone (modules/platform-network). When set, the hub VNet is linked to it so the resolver inbound endpoint can answer for it. | `string` | `null` | no |
| tags | Tags applied to all hub resources. | `map(string)` | `{}` | no |
| transit\_cidrs | Source/destination CIDRs the firewall allows to transit between hubs and spokes. | `list(string)` | <pre>[<br/>  "10.0.0.0/8"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| dns\_resolver\_inbound\_ip | Private IP of the DNS Private Resolver inbound endpoint (the DNS server to point on-prem forwarders at), or null when disabled. |
| firewall\_private\_ip | Private IP of the hub firewall, or null when the firewall is disabled. |
| location | Azure region of the hub. |
| resource\_group\_name | Name of the hub resource group. |
| vnet\_id | Resource ID of the hub virtual network. |
| vnet\_name | Name of the hub virtual network. |
<!-- END_TF_DOCS -->