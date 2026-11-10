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

## Resources

| Name | Type |
| ---- | ---- |
| [azapi_resource_action.register_network](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource_action) | resource |
| [azurerm_management_group.env](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group) | resource |
| [azurerm_management_group.landing_zones](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group) | resource |
| [azurerm_management_group.platform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group) | resource |
| [azurerm_management_group.top](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environments | Environment names, one landing-zone management group each (e.g. ["dev", "prod"]). | `list(string)` | n/a | yes |
| name\_prefix | Prefix for management group IDs (tenant-unique): mg-<prefix>, mg-<prefix>-platform, mg-<prefix>-landingzones, mg-<prefix>-<env>. | `string` | n/a | yes |
| enabled | Create the management group hierarchy and place the subscriptions in it.<br/>Needs tenant-root access once (docs/subscriptions.md). When false this<br/>module creates nothing and top\_management\_group\_id is null, which makes<br/>modules/platform-network fall back to subscription scope - the<br/>single-subscription mode of this repo. | `bool` | `true` | no |
| register\_network\_provider | Register the Microsoft.Network resource provider on the top management group; required before an Azure Virtual Network Manager can be scoped to it. | `bool` | `true` | no |
| subscriptions | Subscription IDs by role: "management" and "connectivity" go under the<br/>platform management group, every other key is an environment name and goes<br/>under that environment's landing-zone management group. Empty values are<br/>skipped (a subscription that does not exist yet). A subscription can only<br/>live in one management group, so when the same ID appears under several<br/>roles the lexically first role wins - in a single-subscription setup the<br/>one subscription lands under "connectivity" (platform). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| management\_group\_ids | Resource IDs of every management group by key: top, platform, landing\_zones, and one per environment. |
| subscription\_placement | Which management group role each known subscription ID was placed under. |
| top\_management\_group\_id | Resource ID of the top management group (the AVNM and policy scope), or null when disabled. |
<!-- END_TF_DOCS -->