# Task backlog

## Now / decisions pending

- [ ] **Firewall on/off decision**: dev currently runs 2× Firewall Basic
      (~$600/mo) for the transit demo. Flip `enable_firewall=false` in
      `live/dev/env.hcl` + re-apply when demo no longer needed.
- [ ] Set GitHub repo variables (AZURE_CLIENT_ID/TENANT/SUBSCRIPTION,
      TG_STATE_*) + OIDC app per docs/github-oidc-setup.md → activates plan.yml.
- [ ] README: replace `git clone <this repo>` with the real URL.

## Next

- [ ] Verify ci.yml went green on GitHub (offline validate path).
- [ ] Verify AKS 0.6.7 `count_of` vs cluster-autoscaler: does a second apply
      try to reset node counts scaled by the autoscaler? (Watch a plan after
      the spot pool has scaled up.)
- [ ] Clean up `hello-eus2` demo workload from the eus2 cluster (or keep as
      standing demo).
- [ ] Consider workload identity example (OIDC issuer already enabled).
- [ ] Consider `az aks stop` schedule / automation note for overnight savings.

## Someday / maybe

- [ ] Third spoke in an existing region to show N-spoke scaling.
- [ ] Private cluster + Bastion example path for prod parity testing.
- [ ] Terragrunt stacks (`terragrunt.stack.hcl`) variant branch for comparison.
- [ ] tflint + checkov in CI (kept out initially for signal/noise).

## Done (this file is append-only history; newest first)

- [x] 2026-07-21 `.claude/` + `.ai/` workspace, git-hook secret gates, /secret-scan skill.
- [x] 2026-07-21 Cross-region transit built + verified (plan 002, 35ba44d).
- [x] 2026-07-21 Terraform-managed RBAC: cluster-admin, Network Contributor (aca1f47, 35ba44d).
- [x] 2026-07-21 dev × 2 regions applied; state bootstrap; providers registered.
- [x] 2026-07-21 Platform foundation + repo published (3c9249a).
