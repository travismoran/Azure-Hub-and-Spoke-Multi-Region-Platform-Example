# Task backlog

## Now / decisions pending

- [ ] Consider trimming Owner at `/` to Management Group Contributor now
      that the hierarchy exists (docs/subscriptions.md).
- [ ] Decide dev defaults after verification: keep `enable_avnm = true` /
      `network_policy = "cilium"` (TEMP markers in live/dev/env.hcl) or
      revert to the $0-AVNM floor; destroy or keep the running dev.
- [ ] Consider renaming the original "Pay-As-You-Go" subscription to
      "management" in the portal (cosmetic; IDs are what matter).

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
      to show IPAM handing out 10.16.4.0/22 and auto-joining the mesh.

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

- [x] 2026-11-02 PR #1 merged to main (plans 003 + 004, 15 commits).

- [x] 2026-11-02 Plan 003 live-verified in dev across subscriptions: IPAM
      stamps, policy membership, global mesh curl (node-IP caller identity),
      Cilium fromCIDR allow/deny, rule 300 vs public LB :22. Five live-only
      fixes. Evidence: .ai/test-results/2026-11-02-avnm-mesh-e2e.md.

- [x] 2026-11-02 prod subscription created + placed under mg-demo-prod
      (1 in-place MG change). Plan 004 complete. PR #1 open, CI green.

- [x] 2026-11-02 live/platform applied + verified (MG tree, AVNM at
      mg-demo, nested IPAM pools, MG policy, 4 commits; $0). Live-only
      fixes: pool display_name, mesh group DirectlyConnected.

- [x] 2026-11-01 Plan 004 code+docs: modules/management-groups, tenant-wide
      platform-network at MG scope with nested IPAM pools, subscription
      placement in root.hcl, renumbered address plan, register-providers.sh,
      docs/subscriptions.md. Providers registered in connectivity + dev.
      Offline validate 10/10. Branch feat/avnm-ipam-mesh.

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
