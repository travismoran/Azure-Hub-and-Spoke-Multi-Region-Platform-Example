<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11, < 2.0 |
| azuread | >= 3.0, < 4.0 |
| time | >= 0.12, < 1.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azuread | >= 3.0, < 4.0 |
| time | >= 0.12, < 1.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azuread_application.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_password.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_service_principal.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [time_rotating.secret](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| description | What the principal is for; shown on the app registration and the service principal. | `string` | n/a | yes |
| display\_name | Display name of the application and service principal (e.g. sp-eso-local). | `string` | n/a | yes |
| owner\_object\_ids | Object IDs that own the application and service principal. Include the applying principal and any pipeline identity that must manage it with Application.ReadWrite.OwnedBy. | `set(string)` | n/a | yes |
| secret\_display\_name | Display name of the client secret in the app registration. | `string` | `"client secret"` | no |
| secret\_rotation\_days | Lifetime of the client secret in days; Terraform rotates it on the first apply after it elapses. 730 (24 months) is the Entra portal maximum. | `number` | `730` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| application\_object\_id | Object ID of the application registration. |
| client\_id | Application (client) ID. |
| client\_secret | The client secret. SECRET: never write it to a file in any repo. |
| object\_id | Object ID of the service principal (use as role assignment principal\_id). |
| secret\_end\_date | Expiry of the client secret (RFC 3339). |
<!-- END_TF_DOCS -->