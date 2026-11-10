<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11, < 2.0 |
| azapi | >= 2.12, < 3.0 |
| azuread | >= 3.0, < 4.0 |
| azurerm | >= 4.81, < 5.0 |
| random | >= 3.5, < 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azuread | >= 3.0, < 4.0 |
| azurerm | >= 4.81, < 5.0 |
| random | >= 3.5, < 4.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| key\_vault | git::https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault.git | 7c53adbc7f4f716fa00b21af90e1a120db5e19ef |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_key_vault_secret.operator_managed](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [random_password.generated](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azuread_service_principals.officers](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principals) | data source |
| [azuread_service_principals.readers](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principals) | data source |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region of the vault (and resource group when created here). | `string` | n/a | yes |
| name | Key Vault name: 3-24 alphanumerics and dashes, globally unique (convention kv-<prefix>-<environment>). | `string` | n/a | yes |
| resource\_group\_name | Resource group of the vault; created here when create\_resource\_group is true, otherwise it must exist. | `string` | n/a | yes |
| additional\_officer\_principal\_ids | Extra object IDs granted Key Vault Secrets Officer. | `set(string)` | `[]` | no |
| create\_resource\_group | Create resource\_group\_name here (true for an environment vault; false when the caller owns the group, e.g. modules/local-cluster). | `bool` | `true` | no |
| enable\_telemetry | Enable AVM module telemetry. Off by default: no phone-home from this platform. | `bool` | `false` | no |
| generated\_secrets | Secrets generated here with random\_password (32 chars), keyed by a stable key: key => secret name. | `map(string)` | `{}` | no |
| managed\_secret\_values | Values of managed\_secrets, same keys. Sensitive. | `map(string)` | `{}` | no |
| managed\_secrets | Secrets whose value Terraform owns, keyed by a stable key (the same key indexes managed\_secret\_values): { name, content\_type, tags }. | <pre>map(object({<br/>    name         = string<br/>    content_type = optional(string, "text/plain")<br/>    tags         = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| officer\_service\_principal\_names | Display names of service principals granted Key Vault Secrets Officer (pipeline identities that apply Terraform). The applying principal is always included. Missing names are ignored. | `list(string)` | <pre>[<br/>  "gh-cloud-platform-deploy"<br/>]</pre> | no |
| operator\_managed\_secret\_names | Secrets created as placeholders (value REPLACE\_ME) whose real value an operator sets once with `az keyvault secret set`; Terraform ignores later changes to them. | `list(string)` | `[]` | no |
| purge\_protection\_enabled | Key Vault purge protection. Off for development vaults so `destroy` can purge them; cannot be disabled once on. | `bool` | `false` | no |
| reader\_service\_principal\_names | Display names of service principals granted Key Vault Secrets User (read): the plan pipeline identity, which must refresh the managed secrets' state. Missing names are ignored. | `list(string)` | <pre>[<br/>  "gh-cloud-platform-plan"<br/>]</pre> | no |
| secrets\_user\_principals | Principals granted Key Vault Secrets User (read), keyed by a stable name: { principal\_id, principal\_type (ServicePrincipal/User/Group), description }. Consumers created after the vault (AKS workload identities) grant themselves instead. | <pre>map(object({<br/>    principal_id   = string<br/>    principal_type = optional(string, "ServicePrincipal")<br/>    description    = optional(string, null)<br/>  }))</pre> | `{}` | no |
| soft\_delete\_retention\_days | Key Vault soft-delete retention (7-90). | `number` | `7` | no |
| tags | Tags applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| managed\_secret\_names | Secret names Terraform maintains the value of (managed + generated). |
| name | Key Vault name. |
| operator\_secret\_names | Placeholder secrets whose real value an operator must set by hand. |
| resource\_group\_name | Resource group holding the vault. |
| resource\_id | Key Vault resource ID (scope for Key Vault Secrets User grants). |
| tenant\_id | Tenant of the vault (ClusterSecretStore spec.provider.azurekv.tenantId). |
| uri | Key Vault URI (ClusterSecretStore spec.provider.azurekv.vaultUrl). |
<!-- END_TF_DOCS -->