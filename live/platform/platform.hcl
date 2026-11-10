# Tenant-level platform configuration: what exists above the environments.
# Read by live/_envcommon/management-groups.hcl and platform-network.hcl.
# Subscription IDs come from env vars (never committed) - see .env.example.

locals {
  name_prefix = get_env("TG_NAME_PREFIX", "demo")

  # Environment folders under live/ that hold an env.hcl. Each gets a
  # landing-zone management group, and its region.hcl files feed the IPAM
  # pools and security admin rules.
  environments = ["dev", "prod"]

  # Environments that run outside Azure and get only a public DNS zone
  # (<name>.<public_dns_parent_zone>), a Key Vault and optionally a Basic
  # ACR: no subscription, management group, hub or stamp. "local" is a
  # laptop cluster (e.g. Rancher Desktop / k3s) used to develop Argo CD app
  # deployments; live/dev/local/local-cluster is its Azure footprint.
  # Opt in with TG_ENABLE_LOCAL_CLUSTER=true; with public DNS on it also
  # gets a zone and DNS credentials (README.md "Local cluster ...").
  external_environments = get_env("TG_ENABLE_LOCAL_CLUSTER", "false") == "true" ? ["local"] : []

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

  # Guardrail policy: stamp VNets must allocate from an environment IPAM
  # pool. Off until the platform has been applied once; then Audit, and
  # Deny once the compliance view is clean (docs/network-platform.md).
  enable_ipam_pool_policy = false
  ipam_pool_policy_effect = "Audit"

  # Central private DNS zones are svc.<env>.<this> (env.hcl enable_private_dns).
  private_dns_base_domain = "platform.internal"

  # --- Public DNS (docs/dns.md) ---
  # One zone per cloud under your organisation's apex (e.g.
  # azure.example.com), delegated from the registrar once; every
  # environment gets <env>.azure.example.com delegated from it
  # automatically. Shared by all environments -> applied with the platform,
  # treated as production. ~$0.50/zone/month. Off until
  # TG_PUBLIC_DNS_PARENT_ZONE names a zone you own (a real value, so it
  # comes from the environment, not Git).
  enable_public_dns      = get_env("TG_PUBLIC_DNS_PARENT_ZONE", "") != ""
  public_dns_parent_zone = get_env("TG_PUBLIC_DNS_PARENT_ZONE", "azure.example.com")

  # Credentials for the external environments' zones (live/platform/dns-principals,
  # docs/identity.md §5): one service principal per external environment with
  # DNS Zone Contributor on its zone only. Its client secret is the documented
  # exception to the no-secret rule; 730 days (24 months) is the Entra portal
  # maximum and Terraform rotates it on the first apply after it elapses.
  # The deploy pipeline identity is made an owner so it can manage the apps
  # with Application.ReadWrite.OwnedBy alone.
  dns_principal_secret_days    = 730
  dns_principal_owner_sp_names = ["gh-cloud-platform-deploy"]
}
