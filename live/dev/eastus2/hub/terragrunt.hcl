include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/hub.hcl"
  expose         = true
  merge_strategy = "deep"
}

# This hub owns the global hub<->hub peering (declared on exactly one side;
# both directions are created from here), so it depends on the westus3 hub.
dependency "remote_hub" {
  config_path = "../../westus3/hub"

  mock_outputs = {
    firewall_private_ip = null
    location            = "mockregion"
    resource_group_name = "mock-rg-hub-remote"
    vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg-hub-remote/providers/Microsoft.Network/virtualNetworks/mock-vnet-hub-remote"
    vnet_name           = "mock-vnet-hub-remote"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Hub-to-hub transit: forward the remote (dev/westus3) spoke's CIDR to that
# hub's firewall. Firewall private IPs are the first host (.4) of each
# AzureFirewallSubnet - see docs/ipam.md.
inputs = {
  peer_hub = {
    vnet_id             = dependency.remote_hub.outputs.vnet_id
    vnet_name           = dependency.remote_hub.outputs.vnet_name
    resource_group_name = dependency.remote_hub.outputs.resource_group_name
  }

  firewall_route_entries = [
    {
      name                = "to-spoke-dev-wus3"
      address_prefix      = "10.16.0.0/16"
      next_hop_ip_address = "10.0.0.4"
    },
  ]
}
