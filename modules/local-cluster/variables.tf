variable "environment" {
  description = "Name of the external environment (platform.hcl external_environments entry, e.g. local). Used in resource names and the DNS zone."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,12}$", var.environment))
    error_message = "environment must be 1-12 lowercase alphanumerics (it is part of the 24-char Key Vault name)."
  }
}

variable "location" {
  description = "Azure region of the resource group and Key Vault."
  type        = string
}

variable "name_prefix" {
  description = "Global naming prefix (TG_NAME_PREFIX). Key Vault name is kv-<prefix>-<environment>: globally unique, max 24 chars."
  type        = string
  default     = "demo"
}

variable "resource_group_name" {
  description = "Override for the resource group name (default rg-<prefix>-<environment>)."
  type        = string
  default     = null
}

variable "key_vault_name" {
  description = "Override for the Key Vault name (default kv-<prefix>-<environment>; 3-24 alphanumerics and dashes, globally unique)."
  type        = string
  default     = null
}

variable "dns_secrets_present" {
  description = "Whether dns_azure_json / dns_sp_secret carry values (live/platform/dns-principals applied for this environment). Separate non-sensitive flag because secret map keys must be known at plan time and must not derive from sensitive values."
  type        = bool
  default     = false
}

variable "dns_azure_json" {
  description = "external-dns Azure provider config (azure.json) for this environment, from live/platform/dns-principals `azure_json[<env>]`. Empty string = not yet available, secret skipped."
  type        = string
  default     = ""
  sensitive   = true
}

variable "dns_sp_secret" {
  description = "Client secret of sp-dns-<env> for cert-manager's azureDNS solver, from live/platform/dns-principals `client_secrets[<env>]`. Empty string = not yet available, secret skipped."
  type        = string
  default     = ""
  sensitive   = true
}

variable "secret_rotation_days" {
  description = "Lifetime of the ESO service principal's client secret in days (portal maximum 730)."
  type        = number
  default     = 730
}

variable "owner_service_principal_names" {
  description = "Display names of service principals made owners of the ESO application and Key Vault Secrets Officers (pipeline identities). Missing names are ignored."
  type        = list(string)
  default     = ["gh-cloud-platform-deploy"]
}

variable "operator_managed_secret_names" {
  description = "Key Vault secrets created as placeholders (value REPLACE_ME) whose real value an operator sets once with `az keyvault secret set`; Terraform ignores later changes to them."
  type        = list(string)
  default     = ["google-oauth-client-id", "google-oauth-client-secret"]
}

variable "reader_service_principal_names" {
  description = "Display names of service principals granted Key Vault Secrets User (the plan pipeline identity). Missing names are ignored."
  type        = list(string)
  default     = ["gh-cloud-platform-plan"]
}

variable "purge_protection_enabled" {
  description = "Key Vault purge protection. Off for development vaults so `destroy` can purge them; cannot be disabled once on."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Key Vault soft-delete retention (7-90)."
  type        = number
  default     = 7
}

variable "enable_telemetry" {
  description = "Enable AVM module telemetry. Off by default: no phone-home from this platform."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

# --- Container registry (acr.tf, ADR-026) -------------------------------------

variable "enable_acr" {
  description = "Create a container registry for the environment's images, with one GitHub Actions push identity per acr_push_repositories entry and a repository-scoped pull token in the vault. Basic SKU ~$5/month."
  type        = bool
  default     = false
}

variable "acr_name" {
  description = "Override for the registry name (default cr<prefix><environment>; 5-50 alphanumerics, globally unique)."
  type        = string
  default     = null

  validation {
    condition     = var.acr_name == null || can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be 5-50 alphanumerics."
  }
}

variable "acr_sku" {
  description = "Registry SKU. Basic is the cheapest (10 GB, no network rules); Standard/Premium only if storage or features demand it."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard or Premium."
  }
}

variable "acr_push_repositories" {
  description = "GitHub repositories whose Actions may push to the registry, keyed by image name: { repository = owner/name, subject_prefix = GitHub OIDC sub_claim_prefix (required with immutable subjects; null/empty = repo:<repository>), subjects = allowed subject suffixes (default ref:refs/heads/main) }. Each key gets a managed identity id-gh-<key>-<environment> with AcrPush."
  type = map(object({
    repository     = string
    subject_prefix = optional(string, null)
    subjects       = optional(list(string), ["ref:refs/heads/main"])
  }))
  default = {}

  validation {
    condition     = alltrue([for k, _ in var.acr_push_repositories : can(regex("^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$", k))])
    error_message = "acr_push_repositories keys are image names: 1-32 lowercase alphanumerics and dashes."
  }
}

variable "acr_pull_repositories" {
  description = "Registry repositories (image names) the cluster's pull token may read. null = the keys of acr_push_repositories."
  type        = list(string)
  default     = null
}
