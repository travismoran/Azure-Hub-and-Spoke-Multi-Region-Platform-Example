<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11, < 2.0 |
| azurerm | >= 4.46, < 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | >= 4.46, < 5.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| private\_dns\_zone | git::https://github.com/Azure/terraform-azurerm-avm-res-network-privatednszone.git | 97ed94c12535fac61c3bad293754ba408b8a8d56 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_management_group_policy_assignment.ipam_approved_pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group_policy_assignment) | resource |
| [azurerm_management_group_policy_assignment.ng_stamps](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group_policy_assignment) | resource |
| [azurerm_management_group_policy_assignment.ng_stamps_region](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group_policy_assignment) | resource |
| [azurerm_network_manager.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager) | resource |
| [azurerm_network_manager_admin_rule.allow_from_hubs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_admin_rule) | resource |
| [azurerm_network_manager_admin_rule.deny_cross_env](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_admin_rule) | resource |
| [azurerm_network_manager_admin_rule.deny_internet_high_risk_ports](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_admin_rule) | resource |
| [azurerm_network_manager_admin_rule_collection.stamps](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_admin_rule_collection) | resource |
| [azurerm_network_manager_connectivity_configuration.mesh](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_connectivity_configuration) | resource |
| [azurerm_network_manager_deployment.connectivity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_deployment) | resource |
| [azurerm_network_manager_deployment.routing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_deployment) | resource |
| [azurerm_network_manager_deployment.security_admin](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_deployment) | resource |
| [azurerm_network_manager_ipam_pool.env](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_ipam_pool) | resource |
| [azurerm_network_manager_ipam_pool.region](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_ipam_pool) | resource |
| [azurerm_network_manager_network_group.stamps](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_network_group) | resource |
| [azurerm_network_manager_network_group.stamps_region](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_network_group) | resource |
| [azurerm_network_manager_routing_configuration.stamps](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_routing_configuration) | resource |
| [azurerm_network_manager_routing_rule.default_via_firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_routing_rule) | resource |
| [azurerm_network_manager_routing_rule_collection.stamps_region](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_routing_rule_collection) | resource |
| [azurerm_network_manager_security_admin_configuration.stamps](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_manager_security_admin_configuration) | resource |
| [azurerm_policy_definition.ipam_approved_pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_policy_definition.ng_stamps](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_policy_definition.ng_stamps_region](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_resource_group.avnm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_resource_group.dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subscription_policy_assignment.ipam_approved_pool](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.ng_stamps](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.ng_stamps_region](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environments | Every environment, keyed by name, with its per-region stamp pool and hub<br/>ranges (keys of regions must exist in var.regions). enabled = whether the<br/>environment's stamps are IPAM-allocated and meshed (its env.hcl<br/>enable\_avnm): pools, network group, mesh and rules exist only for enabled<br/>environments. Disabled environments still contribute their stamp pools to<br/>the other environments' deny rules, because their stamps use those ranges<br/>statically. | <pre>map(object({<br/>    enabled     = bool<br/>    firewall    = optional(bool, false) # hubs carry a firewall (env.hcl enable_firewall)<br/>    routing     = optional(bool, false) # AVNM pushes 0/0 -> regional hub firewall into stamp route tables (env.hcl enable_avnm_routing)<br/>    private_dns = optional(bool, false) # central private DNS zone svc.<env>.<base> (env.hcl enable_private_dns)<br/>    regions = map(object({<br/>      stamp_pool_prefix = string<br/>      hub_address_space = list(string)<br/>    }))<br/>  }))</pre> | n/a | yes |
| location | Home region of the AVNM instance and its resource group. Pools and commits are per region (see regions). | `string` | n/a | yes |
| regions | Every region of the platform, keyed by short region code. One root IPAM pool<br/>per region over root\_pool\_prefix; environment pools nest inside it, so each<br/>environment's stamp\_pool\_prefix must sit within its region's root. One AVNM<br/>commit per region per scope. | <pre>map(object({<br/>    location         = string<br/>    root_pool_prefix = string<br/>  }))</pre> | n/a | yes |
| enable\_ipam\_pool\_policy | Assign an Azure Policy at the AVNM scope that flags (Audit) or blocks (Deny)<br/>any VNet tagged role=aks-stamp whose address space is not allocated from<br/>one of the environment IPAM pools - i.e. a stamp that bypassed IPAM with a<br/>static prefix. Start with Audit; switch to Deny once compliance is clean. | `bool` | `false` | no |
| enable\_telemetry | Enable AVM module telemetry. Off by default: no phone-home from this platform. | `bool` | `false` | no |
| enabled | Deploy the network platform (Azure Virtual Network Manager, IPAM pools, the<br/>stamp network groups, the global meshes and security admin rules). The AVNM<br/>instance and empty pools cost nothing; AVNM bills per managed VNet (~$0.10/hr<br/>for every VNet that has a deployed configuration) and IPAM bills per active<br/>IP, so cost only starts when an environment with enable\_avnm = true applies<br/>stamps. When false this module creates nothing and every output is<br/>null/empty. | `bool` | `false` | no |
| high\_risk\_inbound\_ports | TCP ports denied inbound from the Internet service tag on every stamp VNet. | `list(string)` | <pre>[<br/>  "22",<br/>  "3389",<br/>  "445",<br/>  "1433"<br/>]</pre> | no |
| ipam\_pool\_policy\_effect | Effect of the approved-pool policy: Audit or Deny. | `string` | `"Audit"` | no |
| management\_group\_id | Resource ID of the management group the AVNM instance and the membership<br/>policies are scoped to (every subscription beneath it is covered). Null<br/>scopes both to the subscription this module deploys into instead - the<br/>single-subscription mode, where that subscription holds stamps as well. | `string` | `null` | no |
| private\_dns\_base\_domain | Base of the per-environment central private DNS zones: svc.<env>.<base>. Zones are created in rg-dns-platform for every environment with private\_dns = true. | `string` | `"platform.internal"` | no |
| tags | Tags applied to all network platform resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| ipam\_pool\_ids | IPAM pool resource IDs keyed by environment, then short region code (empty when disabled). A stamp allocates its VNet from its environment's pool in its region. |
| ipam\_pool\_prefixes | Address prefix of each environment/region stamp pool keyed by environment, then short region code (empty when disabled). |
| network\_group\_ids | Resource ID of each environment's stamp network group, keyed by environment (empty when disabled). |
| network\_manager\_id | Resource ID of the AVNM instance, or null when disabled. |
| private\_dns\_zone\_ids | Resource ID of each environment's central private DNS zone (svc.<env>.<base>), keyed by environment; empty when no environment has private\_dns. |
| root\_pool\_ids | Regional root IPAM pool resource IDs keyed by short region code (empty when disabled). |
<!-- END_TF_DOCS -->