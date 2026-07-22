include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/hub.hcl"
  expose         = true
  merge_strategy = "deep"
}

# Hub-to-hub transit: forward the remote (dev/eastus2) spoke's CIDR to that
# hub's firewall. Firewall private IPs are the first host (.4) of each
# AzureFirewallSubnet - see docs/ipam.md.
inputs = {
  firewall_route_entries = [
    {
      name                = "to-spoke-dev-eus2"
      address_prefix      = "10.21.0.0/16"
      next_hop_ip_address = "10.20.0.4"
    },
  ]
}
