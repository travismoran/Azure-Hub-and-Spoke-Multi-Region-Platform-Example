<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11, < 2.0 |
| azuread | >= 3.0, < 4.0 |
| azurerm | >= 4.46, < 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azuread | >= 3.0, < 4.0 |
| azurerm | >= 4.46, < 5.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| principal | ../service-principal | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_role_assignment.zone_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.zone_rg_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azuread_service_principals.owners](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principals) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| zone\_ids | Public DNS zone resource ID per external environment (from the public-dns unit's env\_zone\_ids, filtered to platform.hcl external\_environments). One service principal is created per key. | `map(string)` | n/a | yes |
| enabled | Create the principals. When false nothing is created and every output is empty. | `bool` | `true` | no |
| name\_prefix | Display-name prefix of the applications: <name\_prefix>-<env>. | `string` | `"sp-dns"` | no |
| owner\_service\_principal\_names | Display names of service principals made owners of every application, in addition to the applying principal. Pipeline identities that hold only Application.ReadWrite.OwnedBy must be listed to manage the apps. Missing names are ignored. | `list(string)` | <pre>[<br/>  "gh-cloud-platform-deploy"<br/>]</pre> | no |
| secret\_rotation\_days | Lifetime of each client secret in days; Terraform rotates it on the first apply after it elapses. 730 (24 months) is the longest the Entra portal allows; the Graph API behind Terraform accepts more, and the tenant's app management policy may cap it. | `number` | `730` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| azure\_json | Ready-made external-dns Azure provider config (azure.json) per environment. SECRET: contains aadClientSecret. |
| client\_ids | Application (client) ID of each environment's service principal - goes into the ClusterIssuer (clientID) and azure.json (aadClientId). |
| client\_secrets | Client secret per environment. SECRET: read with `terragrunt output -raw`/-json into the cluster, never into a file in any repo. |
| object\_ids | Object ID of each service principal (role assignment principal). |
| secret\_end\_dates | Expiry of each client secret (RFC 3339); Terraform rotates it on the first apply after this date. |
| tenant\_id | Tenant the principals live in. |
| zone\_names | Zone each principal may write, keyed by environment. |
| zone\_resource\_groups | Resource group holding each environment's zone (ClusterIssuer resourceGroupName, azure.json resourceGroup). |
| zone\_subscription\_ids | Subscription holding each environment's zone (ClusterIssuer subscriptionID, azure.json subscriptionId). |
<!-- END_TF_DOCS -->