variable "environment" {
  description = "Environment name (e.g. dev, prod). Used in resource names."
  type        = string
}

variable "region_short" {
  description = "Short region code used in resource names (e.g. wus3, eus2)."
  type        = string
}

variable "location" {
  description = "Azure region for the spoke resources."
  type        = string
}

variable "name_prefix" {
  description = "Global prefix baked into names that must be globally unique (ACR, Log Analytics). Forks of this repo must change it."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.name_prefix))
    error_message = "name_prefix must be 2-10 lowercase alphanumeric characters (it is embedded in ACR names)."
  }
}

variable "stamp_suffix" {
  description = "Distinguishes additional stamps in the same environment and region: \"\" for the first (aks-spoke), \"-2\" for aks-spoke-2, ... Appended to every resource name and to the stamp-id tag."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^(-[a-z0-9]{1,8})?$", var.stamp_suffix))
    error_message = "stamp_suffix must be empty or a dash followed by 1-8 lowercase alphanumerics (e.g. \"-2\")."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "spoke_address_space" {
  description = <<DESC
Static address space of the stamp VNet, used only when ipam_pool_id is null.
Must be one /<stamp_prefix_length> (a /22 by default): the subnet layout is
carved from it - see docs/ipam.md.
DESC
  type        = list(string)

  validation {
    condition     = length(var.spoke_address_space) == 1 && endswith(var.spoke_address_space[0], "/${var.stamp_prefix_length}")
    error_message = "spoke_address_space must be exactly one CIDR of length stamp_prefix_length (default /22)."
  }
}

variable "ipam_pool_id" {
  description = <<DESC
AVNM IPAM pool to allocate the stamp VNet from (output ipam_pool_ids of
modules/platform-network). When set, the VNet asks for a /<stamp_prefix_length>
and spoke_address_space is ignored; IPAM guarantees it overlaps nothing else
in the pool. null (the default, and whenever enable_avnm is off) means static
addressing. Changing between the two recreates the VNet.
DESC
  type        = string
  default     = null
}

variable "stamp_prefix_length" {
  description = "Prefix length of the stamp VNet. /22 (1,024 addresses) fits ~370 nodes; use /21 for larger stamp classes. The subnet layout scales with it."
  type        = number
  default     = 22

  validation {
    condition     = var.stamp_prefix_length >= 20 && var.stamp_prefix_length <= 23
    error_message = "stamp_prefix_length must be between 20 and 23."
  }
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub virtual network to peer with."
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub virtual network (used in peering names)."
  type        = string
}

variable "firewall_private_ip" {
  description = <<DESC
Private IP of the hub firewall (from the hub's outputs). When set, a route
table on the AKS node subnet sends firewall_routed_cidrs traffic to it,
enabling spoke->hub->hub->spoke transit. More-specific Azure system routes
keep intra-VNet and spoke<->hub traffic direct, and internet egress stays on
the cluster load balancer. null (the default) means no UDRs at all.
DESC
  type        = string
  default     = null
}

variable "firewall_routed_cidrs" {
  description = "Destination CIDRs routed to the hub firewall when firewall_private_ip is set. Pass [] when the AVNM mesh carries east-west traffic (a UDR would override the mesh route)."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "pod_cidr" {
  description = "Pod CIDR for Azure CNI overlay. Non-routed; safe to reuse across clusters."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service CIDR. Non-routed; safe to reuse across clusters."
  type        = string
  default     = "172.20.0.0/16"
}

variable "dns_service_ip" {
  description = "IP for the cluster DNS service; must sit inside service_cidr."
  type        = string
  default     = "172.20.0.10"
}

variable "outbound_type" {
  description = "AKS egress method. loadBalancer is the cheapest; userDefinedRouting sends all internet-bound node traffic to the hub firewall (requires firewall_private_ip and the hub's AKS egress rules)."
  type        = string
  default     = "loadBalancer"

  validation {
    condition     = contains(["loadBalancer", "managedNATGateway", "userDefinedRouting"], var.outbound_type)
    error_message = "outbound_type must be loadBalancer, managedNATGateway, or userDefinedRouting."
  }

  validation {
    condition     = var.outbound_type != "userDefinedRouting" || var.firewall_private_ip != null
    error_message = "outbound_type = userDefinedRouting requires a hub firewall (firewall_private_ip)."
  }
}

variable "avnm_routing" {
  description = "True when the network platform pushes the default route into this stamp's route table via an AVNM routing configuration (env.hcl enable_avnm_routing); the module then does not create its own 0.0.0.0/0 route."
  type        = bool
  default     = false
}

variable "enable_api_server_vnet_integration" {
  description = "Project the API server into the stamp VNet (.0.128/28, delegated to AKS): nodes and pods reach it over private IPs without a private cluster. Free; changing it on a live cluster is an update, not a recreate."
  type        = bool
  default     = false
}

variable "private_dns_zone_id" {
  description = "Resource ID of the environment's central private DNS zone (output private_dns_zone_ids of modules/platform-network). When set, the stamp VNet is linked to it; required for enable_external_dns_identity."
  type        = string
  default     = null
}

variable "public_dns_zone_id" {
  description = "Resource ID of the environment's public DNS zone (<env>.azure.<org>, output env_zone_ids of modules/public-dns). When set together with enable_external_dns_identity, external-dns may also publish public records there."
  type        = string
  default     = null
}

variable "enable_external_dns_identity" {
  description = "Create a workload identity for external-dns (user-assigned identity + federated credential for the cluster's OIDC issuer) with Private DNS Zone Contributor on the zone and Reader on its resource group. Free."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_external_dns_identity || var.private_dns_zone_id != null || var.public_dns_zone_id != null
    error_message = "enable_external_dns_identity requires private_dns_zone_id and/or public_dns_zone_id."
  }
}

variable "external_dns_service_account" {
  description = "namespace/name of the Kubernetes service account external-dns runs as (the federated credential subject)."
  type        = string
  default     = "external-dns/external-dns"

  validation {
    condition     = can(regex("^[a-z0-9-]+/[a-z0-9-]+$", var.external_dns_service_account))
    error_message = "external_dns_service_account must be namespace/name."
  }
}

variable "enable_cert_manager_identity" {
  description = "Create a workload identity for cert-manager (DNS-01 challenges) with DNS Zone Contributor on the environment's public zone. Free; requires public_dns_zone_id."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_cert_manager_identity || var.public_dns_zone_id != null
    error_message = "enable_cert_manager_identity requires public_dns_zone_id."
  }
}

variable "cert_manager_service_account" {
  description = "namespace/name of the Kubernetes service account cert-manager's controller runs as (the federated credential subject)."
  type        = string
  default     = "cert-manager/cert-manager"

  validation {
    condition     = can(regex("^[a-z0-9-]+/[a-z0-9-]+$", var.cert_manager_service_account))
    error_message = "cert_manager_service_account must be namespace/name."
  }
}

variable "key_vault_id" {
  description = "Resource ID of the environment's Key Vault (output resource_id of modules/key-vault via live/<env>/keyvault). Required for enable_external_secrets_identity."
  type        = string
  default     = null
}

variable "enable_external_secrets_identity" {
  description = "Create a workload identity for External Secrets Operator with Key Vault Secrets User on the environment's vault. Free; requires key_vault_id."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_external_secrets_identity || var.key_vault_id != null
    error_message = "enable_external_secrets_identity requires key_vault_id."
  }
}

variable "external_secrets_service_account" {
  description = "namespace/name of the Kubernetes service account External Secrets Operator runs as (the federated credential subject)."
  type        = string
  default     = "external-secrets/external-secrets"

  validation {
    condition     = can(regex("^[a-z0-9-]+/[a-z0-9-]+$", var.external_secrets_service_account))
    error_message = "external_secrets_service_account must be namespace/name."
  }
}

variable "network_policy" {
  description = "Kubernetes network policy engine (azure, calico, cilium) or null for none (cheapest, no policy enforcement overhead). cilium also switches the dataplane to Cilium, as Azure requires."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version. null lets Azure pick the current default GA version; pin explicitly in prod."
  type        = string
  default     = null
}

variable "aks_sku_tier" {
  description = "AKS control plane tier. Free has no uptime SLA but costs nothing; Standard is ~$73/mo per cluster."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier must be Free, Standard, or Premium."
  }
}

variable "private_cluster_enabled" {
  description = "Make the API server private. Off by default: reaching a private API server needs a jumpbox/bastion/VPN, all of which cost money. Use api_server_authorized_ip_ranges instead for cheap dev clusters."
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDRs allowed to reach the public API server. Supply your own IP via the TG_AUTHORIZED_IP env var; never commit real IPs."
  type        = list(string)
  default     = []
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin via AKS-managed Entra integration."
  type        = list(string)
  default     = []
}

variable "cluster_admin_principal_ids" {
  description = <<DESC
Entra ID principal object IDs (users, groups, or service principals) granted
'Azure Kubernetes Service RBAC Cluster Admin' on the cluster scope. Without at
least one entry (or an admin_group_object_ids membership) nobody can use
kubectl, since the cluster runs Azure RBAC with local accounts as the only
fallback. Supply values via env var (e.g. TG_CLUSTER_ADMIN_OBJECT_ID) - never
commit real object IDs. Creating role assignments requires the deploying
identity to hold roleAssignments/write (Owner or User Access Administrator).
DESC
  type        = set(string)
  default     = []
}

variable "system_node_pool" {
  description = "System node pool sizing. Defaults to a single burstable B2ms - the cheapest sensible system node."
  type = object({
    vm_size              = optional(string, "Standard_B2ms")
    min_count            = optional(number, 1)
    max_count            = optional(number, 2)
    os_disk_size_gb      = optional(number)
    availability_zones   = optional(list(string))
    critical_addons_only = optional(bool, true)
  })
  default = {}
}

variable "user_node_pools" {
  description = "User node pools. Empty by default; add Spot pools for cheap burst capacity."
  type = map(object({
    vm_size            = string
    min_count          = optional(number, 0)
    max_count          = optional(number, 2)
    priority           = optional(string, "Regular")
    spot_max_price     = optional(number, -1)
    os_disk_size_gb    = optional(number)
    availability_zones = optional(list(string))
    node_labels        = optional(map(string), {})
    node_taints        = optional(list(string), [])
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Optional components - everything here costs money, so everything is a
# toggle and the expensive ones default to off.
# ---------------------------------------------------------------------------

variable "enable_acr" {
  description = "Create an Azure Container Registry in the spoke."
  type        = bool
  default     = true
}

variable "acr_sku" {
  description = "ACR SKU. Basic (~$5/mo) is plenty for examples; Premium adds private link, geo-replication, zone redundancy."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

variable "acr_grant_kubelet_pull" {
  description = "Grant the cluster kubelet identity AcrPull on the registry. Requires the deploying identity to hold roleAssignments/write (Owner or User Access Administrator)."
  type        = bool
  default     = true
}

variable "enable_log_analytics" {
  description = "Create a Log Analytics workspace (~$2.76/GB ingested). Required by container insights and Defender."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics retention. 30 days is the free retention floor."
  type        = number
  default     = 30
}

variable "enable_container_insights" {
  description = "Enable the container insights (OMS agent) addon. Requires enable_log_analytics."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_container_insights || var.enable_log_analytics
    error_message = "enable_container_insights requires enable_log_analytics = true."
  }
}

variable "enable_managed_prometheus" {
  description = "Create an Azure Monitor workspace (managed Prometheus) and onboard the cluster's metrics into it together with container insights (the AVM module's onboard_monitoring). Workspace is free; metrics ingestion is billed per sample. Requires enable_container_insights."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_managed_prometheus || var.enable_container_insights
    error_message = "enable_managed_prometheus requires enable_container_insights = true."
  }
}

variable "enable_defender" {
  description = "Enable Microsoft Defender for Containers (~$7/vCPU/mo). Requires enable_log_analytics."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_defender || var.enable_log_analytics
    error_message = "enable_defender requires enable_log_analytics = true."
  }
}

variable "enable_azure_policy" {
  description = "Enable the Azure Policy addon for AKS."
  type        = bool
  default     = false
}

variable "enable_workload_identity" {
  description = "Enable OIDC issuer + workload identity. Free, and the modern way to give pods Azure credentials."
  type        = bool
  default     = true
}

variable "enable_telemetry" {
  description = "Enable AVM module telemetry. Off by default to avoid any phone-home from this example."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all spoke resources."
  type        = map(string)
  default     = {}
}
