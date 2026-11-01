# Task backlog

## Now / decisions pending

- [ ] Plan 003 live verification: apply dev with `enable_avnm = true` (both
      regions, no firewalls), prove mesh cluster-to-cluster + policy
      membership + security admin rule; record in .ai/test-results/.
      Then decide: merge feat/avnm-ipam-mesh → main.

- [ ] Set GitHub repo variables (AZURE_CLIENT_ID/TENANT/SUBSCRIPTION,
      TG_STATE_*) + OIDC app per docs/github-oidc-setup.md → activates plan.yml.

## Next

- [ ] Plan 003 follow-ups from the source plan: AVNM routing config
      (UseExisting) once `outbound_type = userDefinedRouting` exists; IPAM
      "VNet must allocate from approved pool" deny policy (Audit first);
      central `svc.platform.internal` zone + external-dns + hub DNS Private
      Resolver (~$180/mo/hub); API server VNet integration subnet; stamp
      catalog → generated Cilium caller policies.
- [ ] N-stamp demo: second aks-spoke in dev/westus3 (`stamp-id` differs)
      to show IPAM handing out 10.11.4.0/22 and auto-joining the mesh.

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

- [x] 2026-11-01 Plan 003 code+docs: modules/platform-network (AVNM, IPAM
      pools, tag-driven network group, global mesh, security admin), stamp
      /22 layout via AVM subnet submodule, Cilium dataplane fix, docs.
      Offline validate 10/10 units. Branch feat/avnm-ipam-mesh.

- [x] 2026-07-25 `enable_firewall` default back to `false` in dev - cheapest
      footprint for forkers; transit demo re-enabled by one toggle.
- [x] 2026-07-22 Full teardown: 72 resources destroyed across both dev regions,
      zero errors/orphans (state + bootstrap preserved). hello-eus2 went with it.
- [x] 2026-07-21 scripts/setup-dev.sh: pinned checksum-verified gitleaks install
      + hook activation; both install paths tested. README clone URL fixed.
- [x] 2026-07-21 `.claude/` + `.ai/` workspace, git-hook secret gates, /secret-scan skill.
- [x] 2026-07-21 Cross-region transit built + verified (plan 002, 35ba44d).
- [x] 2026-07-21 Terraform-managed RBAC: cluster-admin, Network Contributor (aca1f47, 35ba44d).
- [x] 2026-07-21 dev × 2 regions applied; state bootstrap; providers registered.
- [x] 2026-07-21 Platform foundation + repo published (3c9249a).
