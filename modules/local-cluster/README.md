<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11, < 2.0 |
| azuread | >= 3.0, < 4.0 |
| azurerm | >= 4.81, < 5.0 |
| time | >= 0.12, < 1.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azuread | >= 3.0, < 4.0 |
| azurerm | >= 4.81, < 5.0 |
| time | >= 0.12, < 1.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| eso\_principal | ../service-principal | n/a |
| push\_identity | ../github-actions-identity | n/a |
| vault | ../key-vault | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_container_registry.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_container_registry_scope_map.pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry_scope_map) | resource |
| [azurerm_container_registry_token.pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry_token) | resource |
| [azurerm_container_registry_token_password.pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry_token_password) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [time_rotating.acr_pull](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azuread_service_principals.owners](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principals) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Name of the external environment (platform.hcl external\_environments entry, e.g. local). Used in resource names and the DNS zone. | `string` | n/a | yes |
| location | Azure region of the resource group and Key Vault. | `string` | n/a | yes |
| acr\_name | Override for the registry name (default cr<prefix><environment>; 5-50 alphanumerics, globally unique). | `string` | `null` | no |
| acr\_pull\_repositories | Registry repositories (image names) the cluster's pull token may read. null = the keys of acr\_push\_repositories. | `list(string)` | `null` | no |
| acr\_push\_repositories | GitHub repositories whose Actions may push to the registry, keyed by image name: { repository = owner/name, subject\_prefix = GitHub OIDC sub\_claim\_prefix (required with immutable subjects; null/empty = repo:<repository>), subjects = allowed subject suffixes (default ref:refs/heads/main) }. Each key gets a managed identity id-gh-<key>-<environment> with AcrPush. | <pre>map(object({<br/>    repository     = string<br/>    subject_prefix = optional(string, null)<br/>    subjects       = optional(list(string), ["ref:refs/heads/main"])<br/>  }))</pre> | `{}` | no |
| acr\_sku | Registry SKU. Basic is the cheapest (10 GB, no network rules); Standard/Premium only if storage or features demand it. | `string` | `"Basic"` | no |
| dns\_azure\_json | external-dns Azure provider config (azure.json) for this environment, from live/platform/dns-principals `azure_json[<env>]`. Empty string = not yet available, secret skipped. | `string` | `""` | no |
| dns\_secrets\_present | Whether dns\_azure\_json / dns\_sp\_secret carry values (live/platform/dns-principals applied for this environment). Separate non-sensitive flag because secret map keys must be known at plan time and must not derive from sensitive values. | `bool` | `false` | no |
| dns\_sp\_secret | Client secret of sp-dns-<env> for cert-manager's azureDNS solver, from live/platform/dns-principals `client_secrets[<env>]`. Empty string = not yet available, secret skipped. | `string` | `""` | no |
| enable\_acr | Create a container registry for the environment's images, with one GitHub Actions push identity per acr\_push\_repositories entry and a repository-scoped pull token in the vault. Basic SKU ~$5/month. | `bool` | `false` | no |
| enable\_telemetry | Enable AVM module telemetry. Off by default: no phone-home from this platform. | `bool` | `false` | no |
| key\_vault\_name | Override for the Key Vault name (default kv-<prefix>-<environment>; 3-24 alphanumerics and dashes, globally unique). | `string` | `null` | no |
| name\_prefix | Global naming prefix (TG\_NAME\_PREFIX). Key Vault name is kv-<prefix>-<environment>: globally unique, max 24 chars. | `string` | `"demo"` | no |
| operator\_managed\_secret\_names | Key Vault secrets created as placeholders (value REPLACE\_ME) whose real value an operator sets once with `az keyvault secret set`; Terraform ignores later changes to them. | `list(string)` | <pre>[<br/>  "google-oauth-client-id",<br/>  "google-oauth-client-secret"<br/>]</pre> | no |
| owner\_service\_principal\_names | Display names of service principals made owners of the ESO application and Key Vault Secrets Officers (pipeline identities). Missing names are ignored. | `list(string)` | <pre>[<br/>  "gh-cloud-platform-deploy"<br/>]</pre> | no |
| purge\_protection\_enabled | Key Vault purge protection. Off for development vaults so `destroy` can purge them; cannot be disabled once on. | `bool` | `false` | no |
| reader\_service\_principal\_names | Display names of service principals granted Key Vault Secrets User (the plan pipeline identity). Missing names are ignored. | `list(string)` | <pre>[<br/>  "gh-cloud-platform-plan"<br/>]</pre> | no |
| resource\_group\_name | Override for the resource group name (default rg-<prefix>-<environment>). | `string` | `null` | no |
| secret\_rotation\_days | Lifetime of the ESO service principal's client secret in days (portal maximum 730). | `number` | `730` | no |
| soft\_delete\_retention\_days | Key Vault soft-delete retention (7-90). | `number` | `7` | no |
| tags | Tags applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| acr\_id | Registry resource ID; null when enable\_acr is false. |
| acr\_login\_server | Registry login server (image prefix, the source repositories' ACR\_LOGIN\_SERVER variable); null when enable\_acr is false. |
| acr\_pull\_password\_end\_date | Expiry of the pull token password; Terraform rotates it on the first apply after this date. |
| acr\_pull\_token\_name | Name of the repository-scoped pull token (the imagePullSecret username; its password is the vault secret acr-pull-password). |
| acr\_push\_client\_ids | Client ID of the push identity per acr\_push\_repositories key: that repository's AZURE\_CLIENT\_ID variable for azure/login. |
| acr\_push\_subjects | Federated OIDC subjects each push identity trusts, per acr\_push\_repositories key. |
| eso\_client\_id | Client ID of sp-eso-<env> (ClusterSecretStore authSecretRef.clientId). |
| eso\_client\_secret | Client secret of sp-eso-<env>. SECRET: goes into the cluster secret external-secrets/azure-kv-sp and nowhere else. |
| eso\_object\_id | Object ID of sp-eso-<env>. |
| eso\_secret\_end\_date | Expiry of the ESO client secret; Terraform rotates it on the first apply after this date. |
| key\_vault\_id | Key Vault resource ID. |
| key\_vault\_name | Key Vault name. |
| key\_vault\_uri | Key Vault URI (ClusterSecretStore spec.provider.azurekv.vaultUrl). |
| managed\_secret\_names | Key Vault secret names Terraform maintains in this vault. |
| operator\_secret\_names | Key Vault secrets created as placeholders whose real value an operator must set by hand (`az keyvault secret set`). |
| resource\_group\_name | Resource group holding the environment's Azure resources. |
| tenant\_id | Tenant (ClusterSecretStore spec.provider.azurekv.tenantId). |
<!-- END_TF_DOCS -->