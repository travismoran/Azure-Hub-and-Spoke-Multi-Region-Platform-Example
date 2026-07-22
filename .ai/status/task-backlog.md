# Task backlog

## Now / decisions pending

- [ ] Set GitHub repo variables (AZURE_CLIENT_ID/TENANT/SUBSCRIPTION,
      TG_STATE_*) + OIDC app per docs/github-oidc-setup.md → activates plan.yml.
- [ ] Decide committed default for `enable_firewall` in `live/dev/env.hcl`:
      currently `true` (transit demo config). Infra is destroyed so nothing
      bills either way, but the committed default determines what the next
      apply costs (~$600/mo/2-regions difference) and what forkers get.

## Next

- [ ] Verify ci.yml went green on GitHub (offline validate path).
- [ ] Verify AKS 0.6.7 `count_of` vs cluster-autoscaler: does a second apply
      try to reset node counts scaled by the autoscaler? (Watch a plan after
      the spot pool has scaled up.)
- [ ] Consider workload identity example (OIDC issuer already enabled).
- [ ] Consider `az aks stop` schedule / automation note for overnight savings.

## Someday / maybe

- [ ] Third spoke in an existing region to show N-spoke scaling.
- [ ] Private cluster + Bastion example path for prod parity testing.
- [ ] Terragrunt stacks (`terragrunt.stack.hcl`) variant branch for comparison.
- [ ] tflint + checkov in CI (kept out initially for signal/noise).

## Done (this file is append-only history; newest first)

- [x] 2026-07-22 Full teardown: 72 resources destroyed across both dev regions,
      zero errors/orphans (state + bootstrap preserved). hello-eus2 went with it.
- [x] 2026-07-21 scripts/setup-dev.sh: pinned checksum-verified gitleaks install
      + hook activation; both install paths tested. README clone URL fixed.
- [x] 2026-07-21 `.claude/` + `.ai/` workspace, git-hook secret gates, /secret-scan skill.
- [x] 2026-07-21 Cross-region transit built + verified (plan 002, 35ba44d).
- [x] 2026-07-21 Terraform-managed RBAC: cluster-admin, Network Contributor (aca1f47, 35ba44d).
- [x] 2026-07-21 dev × 2 regions applied; state bootstrap; providers registered.
- [x] 2026-07-21 Platform foundation + repo published (3c9249a).
