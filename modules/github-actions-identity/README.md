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
| location | Azure region of the identity. | `string` | n/a | yes |
| name | Name of the user-assigned managed identity (convention id-gh-<repo>-<environment>). | `string` | n/a | yes |
| repository | GitHub repository the identity is for, as owner/name (e.g. your-org/app-a). Used for the default subject prefix repo:<owner>/<name>. | `string` | n/a | yes |
| resource\_group\_name | Resource group of the identity (the environment's resource group). | `string` | n/a | yes |
| enable\_telemetry | Enable AVM module telemetry. Off by default: no phone-home from this platform. | `bool` | `false` | no |
| role\_assignments | Roles the identity holds, keyed by a stable name: { scope = <resource id>, role\_definition\_name = <built-in role>, description = optional }. Scope the narrowest resource that works (one registry, one storage container); never a subscription. | <pre>map(object({<br/>    scope                = string<br/>    role_definition_name = string<br/>    description          = optional(string, null)<br/>  }))</pre> | `{}` | no |
| subject\_prefix | GitHub OIDC subject prefix for the repository (`gh api repos/<owner>/<name>/actions/oidc/customization/sub`, field sub\_claim\_prefix). Required when the repository uses immutable subjects (repo:<owner>@<id>/<name>@<id>); null or empty = repo:<repository>. | `string` | `null` | no |
| subjects | Subject suffixes that may assume the identity, e.g. ref:refs/heads/main, ref:refs/tags/v1.2.3, environment:prod, pull\_request. One federated credential each (identity limit 20). | `list(string)` | <pre>[<br/>  "ref:refs/heads/main"<br/>]</pre> | no |
| tags | Tags applied to the identity. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| client\_id | Client ID: the repository's AZURE\_CLIENT\_ID variable for azure/login. |
| federated\_subjects | Full OIDC subjects the identity trusts (prefix + suffix), for checking against a failed token exchange. |
| name | Name of the identity. |
| principal\_id | Object (principal) ID of the identity, for role assignments made elsewhere. |
| resource\_id | Resource ID of the identity. |
<!-- END_TF_DOCS -->