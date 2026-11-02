variable "enabled" {
  description = <<DESC
Create the management group hierarchy and place the subscriptions in it.
Needs tenant-root access once (docs/subscriptions.md). When false this
module creates nothing and top_management_group_id is null, which makes
modules/platform-network fall back to subscription scope - the
single-subscription mode of this repo.
DESC
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for management group IDs (tenant-unique): mg-<prefix>, mg-<prefix>-platform, mg-<prefix>-landingzones, mg-<prefix>-<env>."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 1-20 lowercase alphanumerics or dashes."
  }
}

variable "environments" {
  description = "Environment names, one landing-zone management group each (e.g. [\"dev\", \"prod\"])."
  type        = list(string)
}

variable "subscriptions" {
  description = <<DESC
Subscription IDs by role: "management" and "connectivity" go under the
platform management group, every other key is an environment name and goes
under that environment's landing-zone management group. Empty values are
skipped (a subscription that does not exist yet). A subscription can only
live in one management group, so when the same ID appears under several
roles the lexically first role wins - in a single-subscription setup the
one subscription lands under "connectivity" (platform).
DESC
  type        = map(string)
  default     = {}
}

variable "register_network_provider" {
  description = "Register the Microsoft.Network resource provider on the top management group; required before an Azure Virtual Network Manager can be scoped to it."
  type        = bool
  default     = true
}
