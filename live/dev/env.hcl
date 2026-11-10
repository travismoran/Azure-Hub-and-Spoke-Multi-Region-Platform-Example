# dev environment: every knob turned to the cheapest setting.
# Approximate cost with these defaults: ~$75-100/month per region.

locals {
  environment = "dev"
  name_prefix = get_env("TG_NAME_PREFIX", "demo")

  # --- Cluster ---
  kubernetes_version      = null # latest GA picked by Azure; fine for dev
  aks_sku_tier            = "Free"
  private_cluster_enabled = false
  # Lock the public API server down to your own IP (set TG_AUTHORIZED_IP).
  # Empty list = open API server; fine for throwaway clusters, but set it.
  api_server_authorized_ip_ranges = compact([get_env("TG_AUTHORIZED_IP", "")])
  admin_group_object_ids          = []
  # Who can kubectl: your own object id, via env var (never committed).
  #   az ad signed-in-user show --query id -o tsv
  cluster_admin_principal_ids = compact([get_env("TG_CLUSTER_ADMIN_OBJECT_ID", "")])
  network_policy              = "cilium" # TEMP: plan 003 verification needs an enforced policy engine

  system_node_pool = {
    vm_size              = "Standard_D2s_v6" # 2 vCPU / 8 GiB, ~$70/mo. New PAYG subscriptions get 10 vCPU of quota in a few current families only (Dsv6 is one, in both regions); B-series and Dsv5 have none.
    min_count            = 1
    max_count            = 2
    critical_addons_only = true
  }

  # One Spot pool for workloads: scales from zero, evictable, 70-90% cheaper.
  user_node_pools = {
    spot = {
      vm_size   = "Standard_D2s_v6"
      min_count = 0
      max_count = 2
      priority  = "Spot"
    }
  }

  # --- Hub ---
  # Firewalls cost ~$300/mo each even on Basic, so dev defaults to none -
  # regions are isolated and spokes egress via their load balancer. Set true
  # to enable cross-region hub-to-hub transit (see docs/architecture.md);
  # the UDRs, firewall routes, and transit rules all activate automatically.
  # Verified working 2026-07-21: .ai/test-results/2026-07-21-aks-e2e.md
  enable_firewall   = false
  firewall_sku_tier = "Basic"
  # Egress: loadBalancer (cheapest) or userDefinedRouting = everything
  # internet-bound leaves through the hub firewall (requires enable_firewall;
  # the hub then carries the AKS egress rules). Prod's intended end state.
  aks_outbound_type = "loadBalancer"
  # With userDefinedRouting on an AVNM environment, let AVNM push the default
  # route into every stamp's route table instead of each stamp adding its own.
  enable_avnm_routing = false
  # Optional hub services (docs/costs.md): DNS Private Resolver inbound
  # endpoint for on-prem resolution (~$180/mo/hub) and Bastion for reaching
  # private clusters (~$140/mo Basic; Developer is free where offered).
  enable_dns_resolver = false
  enable_bastion      = false
  bastion_sku         = "Basic"

  # --- Network platform: AVNM + IPAM + global mesh (docs/network-platform.md) ---
  # Opt this environment into the tenant-wide AVNM (live/platform/network):
  # every spoke /22 is allocated from this env's IPAM pool and all its
  # spokes join one global mesh (direct cross-region cluster-to-cluster, no
  # firewall needed for east-west), with the other environments' pools
  # denied inbound by security admin rules. AVNM bills per managed VNet
  # (~$0.10/hr each) plus a small per-active-IP IPAM fee, so dev leaves it
  # off: each spoke gets a static /22 from region.hcl and regions stay
  # isolated (or transit via hub firewalls, enable_firewall).
  enable_avnm         = true                   # TEMP: plan 003 live verification (2026-11-02)
  regions             = ["westus3", "eastus2"] # folders here holding a region.hcl
  stamp_prefix_length = 22
  # Additional stamps per region (aks-spoke-2, ...) exist as units but are
  # excluded from run --all until this is true (~$75/mo each in dev).
  enable_extra_stamps = false

  # --- Service discovery across stamps (docs/network-platform.md) ---
  # Central private DNS zone svc.dev.platform.internal, linked to every hub
  # and stamp VNet (~$0.50/mo), and a workload identity per stamp for
  # external-dns to publish into it. Free apart from the zone.
  enable_private_dns = false
  # Workload identities per stamp (free): external-dns and cert-manager write
  # the environment's public zone, External Secrets reads the environment's
  # Key Vault (live/<env>/keyvault). Client IDs are stamp outputs that go into
  # the manifests repo overlays.
  enable_external_dns_identity     = true
  enable_cert_manager_identity     = true
  enable_external_secrets_identity = true
  # Environment Key Vault (modules/key-vault, ~$0.03/10k operations).
  key_vault_purge_protection = false # dev vault must be destroyable
  key_vault_soft_delete_days = 7
  # API server VNet integration: control plane reachable on a private IP in
  # the stamp (.0.128/28) without a private cluster. Free.
  enable_api_server_vnet_integration = false

  # --- Optional components (all the expensive telemetry/security is OFF) ---
  enable_acr                = true # Basic, ~$5/mo
  acr_sku                   = "Basic"
  enable_log_analytics      = false
  log_retention_days        = 30
  enable_container_insights = false
  enable_managed_prometheus = false # Azure Monitor workspace + metrics ingestion; needs container insights
  enable_defender           = false
  enable_azure_policy       = false
  enable_telemetry          = false
}
