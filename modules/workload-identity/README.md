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
| identity | git::https://github.com/Azure/terraform-azurerm-avm-res-managedidentity-userassignedidentity.git | 7a0c461789f0177a0b666378924cd5d33196ef8a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Region of the identity (the cluster's region). | `string` | n/a | yes |
| name | Name of the user-assigned managed identity (convention id-<component>-<cluster>). | `string` | n/a | yes |
| oidc\_issuer\_url | The cluster's OIDC issuer URL (AKS oidc\_issuer\_profile.issuer\_url). | `string` | n/a | yes |
| resource\_group\_name | Resource group of the identity (the cluster's stamp resource group). | `string` | n/a | yes |
| service\_account | namespace/name of the Kubernetes service account this identity is bound to (federated credential subject system:serviceaccount:<namespace>:<name>). | `string` | n/a | yes |
| enable\_telemetry | Enable AVM module telemetry. Off by default: no phone-home from this platform. | `bool` | `false` | no |
| role\_assignments | Roles the identity holds, keyed by a stable name: { scope = <resource id>, role\_definition\_name = <built-in role>, description = optional }. Scope the narrowest resource that works (a zone, a vault, a container); never a subscription. | <pre>map(object({<br/>    scope                = string<br/>    role_definition_name = string<br/>    description          = optional(string, null)<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to the identity. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| client\_id | Client ID: the azure.workload.identity/client-id annotation on the service account. |
| name | Name of the identity. |
| principal\_id | Object (principal) ID of the identity, for role assignments made elsewhere. |
| resource\_id | Resource ID of the identity. |
<!-- END_TF_DOCS -->