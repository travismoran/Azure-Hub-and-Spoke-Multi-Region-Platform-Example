# Tenant-level platform configuration: what exists above the environments.
# Read by live/_envcommon/management-groups.hcl and platform-network.hcl.
# Subscription IDs come from env vars (never committed) - see .env.example.

locals {
  name_prefix = get_env("TG_NAME_PREFIX", "demo")

  # Environment folders under live/ that hold an env.hcl. Each gets a
  # landing-zone management group, and its region.hcl files feed the IPAM
  # pools and security admin rules.
  environments = ["dev", "prod"]

  # Management groups need tenant-root access once (docs/subscriptions.md).
  # false = single-subscription mode: no hierarchy, AVNM scoped to its own
  # subscription.
  enable_management_groups = true

  # Subscriptions by role (same env vars live/root.hcl places units with).
  # An empty environment entry = that subscription does not exist yet; it is
  # skipped and its management group stays empty until the variable is set.
  subscriptions = {
    management   = get_env("TG_SUBSCRIPTION_MANAGEMENT", get_env("ARM_SUBSCRIPTION_ID", ""))
    connectivity = get_env("TG_SUBSCRIPTION_CONNECTIVITY", get_env("ARM_SUBSCRIPTION_ID", ""))
    dev          = get_env("TG_SUBSCRIPTION_DEV", "")
    prod         = get_env("TG_SUBSCRIPTION_PROD", "")
  }

  # --- Network platform (docs/network-platform.md) ---
  # The AVNM instance itself is free; per-VNet billing starts when an
  # environment with enable_avnm = true applies stamps.
  avnm_location = "westus3"

  # Regional root IPAM pools (docs/ipam.md). Every environment's
  # stamp_pool_prefix (region.hcl) must sit inside its region's root.
  regions = {
    wus3 = { location = "westus3", root_pool_prefix = "10.16.0.0/12" }
    eus2 = { location = "eastus2", root_pool_prefix = "10.32.0.0/12" }
  }
}
