include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/public-dns-principals.hcl"
  expose         = true
  merge_strategy = "deep"
}
