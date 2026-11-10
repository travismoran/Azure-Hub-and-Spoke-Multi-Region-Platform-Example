include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/aks-spoke.hcl"
  expose         = true
  merge_strategy = "deep"
}

# Second stamp in this env/region: identical to aks-spoke except the folder
# name, which becomes the "-2" suffix on every resource name and the
# stamp-id tag. IPAM hands it the next /22 of the regional pool and the
# tag-driven network group adds it to the mesh. Excluded from `run --all`
# until env.hcl enable_extra_stamps is true.
exclude {
  if      = !include.envcommon.locals.env.enable_extra_stamps
  actions = ["all"]
}
