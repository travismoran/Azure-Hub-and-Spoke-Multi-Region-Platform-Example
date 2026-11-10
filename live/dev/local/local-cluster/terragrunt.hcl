include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/local-cluster.hcl"
  expose         = true
  merge_strategy = "deep"
}

# Opt-in: excluded from `run --all` until the environment is listed in
# platform.hcl external_environments (TG_ENABLE_LOCAL_CLUSTER=true).
exclude {
  if      = !contains(include.envcommon.locals.platform.external_environments, include.envcommon.locals.external_env)
  actions = ["all"]
}
