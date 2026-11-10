# Task backlog

## Now / decisions pending

- [ ] Remove Owner + User Access Administrator at `/` now that the
      hierarchy is destroyed (re-elevate per docs/subscriptions.md when
      rebuilding). Optionally cancel the connectivity/dev/prod subscriptions.
- [ ] Decide dev defaults: keep `enable_avnm = true` /
      `network_policy = "cilium"` (TEMP markers in live/dev/env.hcl) or
      revert to the ~$75-100/mo no-AVNM floor. Dev is destroyed.
- [ ] Consider renaming the original "Pay-As-You-Go" subscription to
      "management" in the portal (cosmetic; IDs are what matter).

- [ ] GitHub repo variables / OIDC for plan.yml + deploy.yml
      (`GITHUB_REPO=<owner>/<repo> bootstrap/setup-oidc.sh`) - only if this
      repo should run real plans again; otherwise both workflows skip
      themselves and only `ci` runs.

## Next

- [ ] Live-verify the back-ported features (2026-11-10 entry below) in
      this repo - all validate offline, none has evidence in
      `.ai/test-results/` here: UDR / AVNM-routing egress through a hub
      firewall (ADR-016), central private DNS + external-dns (ADR-017),
      `aks-spoke-2` IPAM + mesh join (ADR-018), public DNS + delegation
      (ADR-019), local-cluster footprint (ADR-023..026).

- [ ] Verify ci.yml went green on GitHub (offline validate path).
- [ ] Verify AKS 0.6.7 `count_of` vs cluster-autoscaler: does a second apply
      try to reset node counts scaled by the autoscaler? (Watch a plan after
      the spot pool has scaled up.)

## Someday / maybe

- [ ] Third spoke in an existing region to show N-spoke scaling.
- [ ] Private cluster + Bastion example path for prod parity testing.
- [ ] Terragrunt stacks (`terragrunt.stack.hcl`) variant branch for comparison.

## Done (this file is append-only history; newest first)

- [x] 2026-11-10 Back-ported the features matured in a private deployment
      of this example (ADR-013), scrubbed of real values: SHA-pinned AVM
      sources + tflint/trivy/terraform-docs in CI (ADR-015), deploy.yml +
      aks-schedule.yml + setup-oidc.sh/tenant-access.sh, UDR/AVNM-routing
      egress (ADR-016), central private DNS (ADR-017), extra stamps
      (ADR-018), public DNS (ADR-019, opt-in via TG_PUBLIC_DNS_PARENT_ZONE),
      managed Prometheus (ADR-020), Network Watcher opt-out (ADR-022),
      external environment `local` + DNS/ESO principals + Basic ACR
      (ADR-021/023/024/026, opt-in via TG_ENABLE_LOCAL_CLUSTER), workload
      identities + per-env Key Vault (ADR-025), stamp catalog → Cilium
      caller policies. Code only; see "Live-verify" above.

- [x] 2026-11-07 `live/platform` destroyed by the user; the tenant is no
      longer used by this repo (a private deployment was created from 10a4010).
      This repo is the public example only.

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

- [x] 2026-11-07 Platform teardown: `live/platform` destroyed (29 AVNM/IPAM/
      policy resources + 6 management groups), zero errors; subscriptions back
      under Tenant Root; tenant has no network manager or AVNM policy left.
- [x] 2026-11-02 Dev teardown after plan 003 verification: 46 resources across
      4 units destroyed, zero errors/orphans; IPAM pools released the /22s,
      network groups empty; platform layer ($0) left in place.
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
