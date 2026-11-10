<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11, < 2.0 |
| azapi | >= 2.9, < 3.0 |
| azurerm | >= 4.46, < 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azapi | >= 2.9, < 3.0 |
| azurerm | >= 4.46, < 5.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| acr | git::https://github.com/Azure/terraform-azurerm-avm-res-containerregistry-registry.git | a3f2ae1622b43a69d1c8554beca673bb3fada65c |
| aks | git::https://github.com/Azure/terraform-azurerm-avm-res-containerservice-managedcluster.git | 2d0302e9d8c450df2d1b257c32823b00b3557c96 |
| cert\_manager\_identity | ../workload-identity | n/a |
| external\_dns\_identity | ../workload-identity | n/a |
| external\_secrets\_identity | ../workload-identity | n/a |
| log\_analytics | git::https://github.com/Azure/terraform-azurerm-avm-res-operationalinsights-workspace.git | b4ffa3ff87ac09ff6de3b7014c44b4d213aa302b |
| spoke\_vnet | git::https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork.git | 7700fb912c3e735b2806faee01e7682af425c46d |
| subnet | git::https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork.git//modules/subnet | 7700fb912c3e735b2806faee01e7682af425c46d |

## Resources

| Name | Type |
| ---- | ---- |
| [azapi_resource.private_dns_link](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azurerm_monitor_workspace.prometheus](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_workspace) | resource |
| [azurerm_resource_group.spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.aks_route_table_network_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.aks_vnet_network_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.cluster_admin](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.kubelet_acr_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_route.default_via_firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) | resource |
| [azurerm_route.via_firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) | resource |
| [azurerm_route_table.nodes](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Environment name (e.g. dev, prod). Used in resource names. | `string` | n/a | yes |
| hub\_vnet\_id | Resource ID of the hub virtual network to peer with. | `string` | n/a | yes |
| hub\_vnet\_name | Name of the hub virtual network (used in peering names). | `string` | n/a | yes |
| location | Azure region for the spoke resources. | `string` | n/a | yes |
| name\_prefix | Global prefix baked into names that must be globally unique (ACR, Log Analytics). Forks of this repo must change it. | `string` | n/a | yes |
| region\_short | Short region code used in resource names (e.g. wus3, eus2). | `string` | n/a | yes |
| spoke\_address\_space | Static address space of the stamp VNet, used only when ipam\_pool\_id is null.<br/>Must be one /<stamp\_prefix\_length> (a /22 by default): the subnet layout is<br/>carved from it - see docs/ipam.md. | `list(string)` | n/a | yes |
| acr\_grant\_kubelet\_pull | Grant the cluster kubelet identity AcrPull on the registry. Requires the deploying identity to hold roleAssignments/write (Owner or User Access Administrator). | `bool` | `true` | no |
| acr\_sku | ACR SKU. Basic (~$5/mo) is plenty for examples; Premium adds private link, geo-replication, zone redundancy. | `string` | `"Basic"` | no |
| admin\_group\_object\_ids | Entra ID group object IDs granted cluster-admin via AKS-managed Entra integration. | `list(string)` | `[]` | no |
| aks\_sku\_tier | AKS control plane tier. Free has no uptime SLA but costs nothing; Standard is ~$73/mo per cluster. | `string` | `"Free"` | no |
| api\_server\_authorized\_ip\_ranges | CIDRs allowed to reach the public API server. Supply your own IP via the TG\_AUTHORIZED\_IP env var; never commit real IPs. | `list(string)` | `[]` | no |
| avnm\_routing | True when the network platform pushes the default route into this stamp's route table via an AVNM routing configuration (env.hcl enable\_avnm\_routing); the module then does not create its own 0.0.0.0/0 route. | `bool` | `false` | no |
| cert\_manager\_service\_account | namespace/name of the Kubernetes service account cert-manager's controller runs as (the federated credential subject). | `string` | `"cert-manager/cert-manager"` | no |
| cluster\_admin\_principal\_ids | Entra ID principal object IDs (users, groups, or service principals) granted<br/>'Azure Kubernetes Service RBAC Cluster Admin' on the cluster scope. Without at<br/>least one entry (or an admin\_group\_object\_ids membership) nobody can use<br/>kubectl, since the cluster runs Azure RBAC with local accounts as the only<br/>fallback. Supply values via env var (e.g. TG\_CLUSTER\_ADMIN\_OBJECT\_ID) - never<br/>commit real object IDs. Creating role assignments requires the deploying<br/>identity to hold roleAssignments/write (Owner or User Access Administrator). | `set(string)` | `[]` | no |
| dns\_service\_ip | IP for the cluster DNS service; must sit inside service\_cidr. | `string` | `"172.20.0.10"` | no |
| enable\_acr | Create an Azure Container Registry in the spoke. | `bool` | `true` | no |
| enable\_api\_server\_vnet\_integration | Project the API server into the stamp VNet (.0.128/28, delegated to AKS): nodes and pods reach it over private IPs without a private cluster. Free; changing it on a live cluster is an update, not a recreate. | `bool` | `false` | no |
| enable\_azure\_policy | Enable the Azure Policy addon for AKS. | `bool` | `false` | no |
| enable\_cert\_manager\_identity | Create a workload identity for cert-manager (DNS-01 challenges) with DNS Zone Contributor on the environment's public zone. Free; requires public\_dns\_zone\_id. | `bool` | `false` | no |
| enable\_container\_insights | Enable the container insights (OMS agent) addon. Requires enable\_log\_analytics. | `bool` | `false` | no |
| enable\_defender | Enable Microsoft Defender for Containers (~$7/vCPU/mo). Requires enable\_log\_analytics. | `bool` | `false` | no |
| enable\_external\_dns\_identity | Create a workload identity for external-dns (user-assigned identity + federated credential for the cluster's OIDC issuer) with Private DNS Zone Contributor on the zone and Reader on its resource group. Free. | `bool` | `false` | no |
| enable\_external\_secrets\_identity | Create a workload identity for External Secrets Operator with Key Vault Secrets User on the environment's vault. Free; requires key\_vault\_id. | `bool` | `false` | no |
| enable\_log\_analytics | Create a Log Analytics workspace (~$2.76/GB ingested). Required by container insights and Defender. | `bool` | `false` | no |
| enable\_managed\_prometheus | Create an Azure Monitor workspace (managed Prometheus) and onboard the cluster's metrics into it together with container insights (the AVM module's onboard\_monitoring). Workspace is free; metrics ingestion is billed per sample. Requires enable\_container\_insights. | `bool` | `false` | no |
| enable\_telemetry | Enable AVM module telemetry. Off by default to avoid any phone-home from this example. | `bool` | `false` | no |
| enable\_workload\_identity | Enable OIDC issuer + workload identity. Free, and the modern way to give pods Azure credentials. | `bool` | `true` | no |
| external\_dns\_service\_account | namespace/name of the Kubernetes service account external-dns runs as (the federated credential subject). | `string` | `"external-dns/external-dns"` | no |
| external\_secrets\_service\_account | namespace/name of the Kubernetes service account External Secrets Operator runs as (the federated credential subject). | `string` | `"external-secrets/external-secrets"` | no |
| firewall\_private\_ip | Private IP of the hub firewall (from the hub's outputs). When set, a route<br/>table on the AKS node subnet sends firewall\_routed\_cidrs traffic to it,<br/>enabling spoke->hub->hub->spoke transit. More-specific Azure system routes<br/>keep intra-VNet and spoke<->hub traffic direct, and internet egress stays on<br/>the cluster load balancer. null (the default) means no UDRs at all. | `string` | `null` | no |
| firewall\_routed\_cidrs | Destination CIDRs routed to the hub firewall when firewall\_private\_ip is set. Pass [] when the AVNM mesh carries east-west traffic (a UDR would override the mesh route). | `list(string)` | <pre>[<br/>  "10.0.0.0/8"<br/>]</pre> | no |
| ipam\_pool\_id | AVNM IPAM pool to allocate the stamp VNet from (output ipam\_pool\_ids of<br/>modules/platform-network). When set, the VNet asks for a /<stamp\_prefix\_length><br/>and spoke\_address\_space is ignored; IPAM guarantees it overlaps nothing else<br/>in the pool. null (the default, and whenever enable\_avnm is off) means static<br/>addressing. Changing between the two recreates the VNet. | `string` | `null` | no |
| key\_vault\_id | Resource ID of the environment's Key Vault (output resource\_id of modules/key-vault via live/<env>/keyvault). Required for enable\_external\_secrets\_identity. | `string` | `null` | no |
| kubernetes\_version | Kubernetes version. null lets Azure pick the current default GA version; pin explicitly in prod. | `string` | `null` | no |
| log\_retention\_days | Log Analytics retention. 30 days is the free retention floor. | `number` | `30` | no |
| network\_policy | Kubernetes network policy engine (azure, calico, cilium) or null for none (cheapest, no policy enforcement overhead). cilium also switches the dataplane to Cilium, as Azure requires. | `string` | `null` | no |
| outbound\_type | AKS egress method. loadBalancer is the cheapest; userDefinedRouting sends all internet-bound node traffic to the hub firewall (requires firewall\_private\_ip and the hub's AKS egress rules). | `string` | `"loadBalancer"` | no |
| pod\_cidr | Pod CIDR for Azure CNI overlay. Non-routed; safe to reuse across clusters. | `string` | `"192.168.0.0/16"` | no |
| private\_cluster\_enabled | Make the API server private. Off by default: reaching a private API server needs a jumpbox/bastion/VPN, all of which cost money. Use api\_server\_authorized\_ip\_ranges instead for cheap dev clusters. | `bool` | `false` | no |
| private\_dns\_zone\_id | Resource ID of the environment's central private DNS zone (output private\_dns\_zone\_ids of modules/platform-network). When set, the stamp VNet is linked to it; required for enable\_external\_dns\_identity. | `string` | `null` | no |
| public\_dns\_zone\_id | Resource ID of the environment's public DNS zone (<env>.azure.<org>, output env\_zone\_ids of modules/public-dns). When set together with enable\_external\_dns\_identity, external-dns may also publish public records there. | `string` | `null` | no |
| service\_cidr | Kubernetes service CIDR. Non-routed; safe to reuse across clusters. | `string` | `"172.20.0.0/16"` | no |
| stamp\_prefix\_length | Prefix length of the stamp VNet. /22 (1,024 addresses) fits ~370 nodes; use /21 for larger stamp classes. The subnet layout scales with it. | `number` | `22` | no |
| stamp\_suffix | Distinguishes additional stamps in the same environment and region: "" for the first (aks-spoke), "-2" for aks-spoke-2, ... Appended to every resource name and to the stamp-id tag. | `string` | `""` | no |
| system\_node\_pool | System node pool sizing. Defaults to a single burstable B2ms - the cheapest sensible system node. | <pre>object({<br/>    vm_size              = optional(string, "Standard_B2ms")<br/>    min_count            = optional(number, 1)<br/>    max_count            = optional(number, 2)<br/>    os_disk_size_gb      = optional(number)<br/>    availability_zones   = optional(list(string))<br/>    critical_addons_only = optional(bool, true)<br/>  })</pre> | `{}` | no |
| tags | Tags applied to all spoke resources. | `map(string)` | `{}` | no |
| user\_node\_pools | User node pools. Empty by default; add Spot pools for cheap burst capacity. | <pre>map(object({<br/>    vm_size            = string<br/>    min_count          = optional(number, 0)<br/>    max_count          = optional(number, 2)<br/>    priority           = optional(string, "Regular")<br/>    spot_max_price     = optional(number, -1)<br/>    os_disk_size_gb    = optional(number)<br/>    availability_zones = optional(list(string))<br/>    node_labels        = optional(map(string), {})<br/>    node_taints        = optional(list(string), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| acr\_login\_server | Login server of the ACR, or null when ACR is disabled. |
| cert\_manager\_client\_id | Client ID of the cert-manager workload identity (ClusterIssuer managedIdentity.clientID and the service account annotation), or null when disabled. |
| cluster\_id | Resource ID of the AKS cluster. |
| cluster\_name | Name of the AKS cluster. |
| external\_dns\_client\_id | Client ID of the external-dns workload identity (service account annotation azure.workload.identity/client-id), or null when disabled. |
| external\_secrets\_client\_id | Client ID of the External Secrets Operator workload identity (service account annotation; ClusterSecretStore authType WorkloadIdentity), or null when disabled. |
| kubelet\_identity\_object\_id | Object ID of the kubelet managed identity (used for AcrPull grants). |
| log\_analytics\_workspace\_id | Resource ID of the Log Analytics workspace, or null when disabled. |
| node\_resource\_group | Name of the AKS-managed node resource group. |
| node\_subnet\_prefixes | Prefixes of the node subnets. Unique per stamp, so other stamps can use them as the caller identity in Cilium/Kubernetes network policies. |
| oidc\_issuer\_url | OIDC issuer URL for workload identity federation. |
| private\_dns\_zone\_name | Name of the environment's central private DNS zone this stamp is linked to, or null. |
| prometheus\_workspace\_id | Resource ID of the Azure Monitor workspace (managed Prometheus), or null when disabled. |
| public\_dns\_zone\_name | Name of the environment's public DNS zone (<env>.azure.<org>) this stamp's external-dns may publish into, or null. |
| spoke\_address\_space | Prefix of the stamp VNet (static, or as allocated by AVNM IPAM). |
| spoke\_vnet\_id | Resource ID of the spoke virtual network. |
| spoke\_vnet\_name | Name of the spoke virtual network. |
| stamp\_id | Stamp identifier (<prefix>-<env>-<region><suffix>), also the stamp-id tag on the VNet. |
| subnet\_ids | Subnet resource IDs keyed by layout name (aks-system, aks-user, ilb, pe). |
<!-- END_TF_DOCS -->