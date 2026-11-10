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
| env\_zone | git::https://github.com/Azure/terraform-azurerm-avm-res-network-dnszone.git | 5678e5b61e6ac24affc7c7aab03478edbe8c696e |
| parent\_zone | git::https://github.com/Azure/terraform-azurerm-avm-res-network-dnszone.git | 5678e5b61e6ac24affc7c7aab03478edbe8c696e |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_resource_group.dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environments | Environment names; each gets a child zone <env>.<parent\_zone> and an NS delegation record in the parent. | `list(string)` | n/a | yes |
| location | Region of the resource group (DNS zones themselves are global). | `string` | n/a | yes |
| parent\_zone | Public DNS zone for this cloud, delegated from the organisation's apex at the registrar (e.g. azure.example.com; another cloud could use aws.example.com the same way). Every environment gets <env>.<parent\_zone> delegated from it here. | `string` | n/a | yes |
| delegation\_ttl | TTL in seconds of the NS delegation records in the parent zone. | `number` | `3600` | no |
| enable\_telemetry | Enable AVM module telemetry. Off by default: no phone-home from this platform. | `bool` | `false` | no |
| enabled | Create the public DNS hierarchy. When false nothing is created and every output is null/empty (stamps then get no public zone to publish into). | `bool` | `true` | no |
| resource\_group\_name | Resource group holding the parent and environment zones. | `string` | `"rg-dns-public"` | no |
| tags | Tags applied to all public DNS resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| env\_zone\_ids | Resource ID of each environment's public zone (<env>.<parent\_zone>), keyed by environment. |
| env\_zone\_names | Name of each environment's public zone, keyed by environment. |
| parent\_name\_servers | Azure DNS name servers of the parent zone - the NS records to create ONCE at the registrar for the parent\_zone label (empty when disabled). |
| parent\_zone\_id | Resource ID of the parent public zone, or null when disabled. |
| parent\_zone\_name | Name of the parent public zone (e.g. azure.example.com), or null when disabled. |
| resource\_group\_name | Resource group holding the zones (grant Reader here for external-dns), or null when disabled. |
<!-- END_TF_DOCS -->