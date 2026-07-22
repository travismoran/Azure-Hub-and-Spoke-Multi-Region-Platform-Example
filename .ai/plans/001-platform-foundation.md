# 001 - Platform foundation: DRY terragrunt hub-spoke AKS

- **Status**: complete
- **Date**: 2026-07-21
- **Commits**: 3c9249a (platform), aca1f47 (terraform-managed cluster-admin)

## Context

Public example of a scalable, DRY, multi-env multi-region AKS platform on
hub-and-spoke networking, inspired by `Azure/terraform-azurerm-avm-ptn-aks-enterprise`
but cost-minimized. That module (v0.1.0) was rejected: hardcodes ~$1,700/mo
(Firewall Standard, D16ds_v5, ACR Premium, private+UDR), creates its own VNet,
exports no VNet ID - hub-spoke impossible. Full rationale: ADR-001.

## Design (as built)

- `modules/hub` wraps avm-ptn-hubnetworking 0.13.2 (firewall optional);
  `modules/aks-spoke` composes vnet 0.19.0 + peering (reverse from spoke
  side) + managedcluster 0.6.7 (azapi-based) + ACR 0.5.1 + LAW 0.5.1.
- `live/` classic-includes hierarchy: root.hcl (backend+provider gen from
  env vars, local-backend fallback when TG_STATE_* unset) → env.hcl
  (all toggles) → region.hcl (CIDRs from docs/ipam.md) → _envcommon → 8-line
  leaves. dev+prod × westus3+eastus2.
- Cost defaults: AKS Free, 1× B2ms system + Spot-from-zero user pool, ACR
  Basic, no firewall/LAW/insights/Defender/telemetry. Prod flips everything.
- Zero secrets: .env (gitignored) + OIDC plan-only CI + gitleaks.

## Verification (done)

- Full 8-unit graph: `terragrunt run --all -- validate` offline ✅
- dev/westus3 applied: 18 resources + role assignment; kubectl verified ✅
- dev/eastus2 applied: 19 resources; kubectl worked with zero manual steps ✅
- State in Azure Storage (RBAC-only), bootstrap script idempotent ✅

## Follow-ups discovered

- BYO-VNet Network Contributor gap → fixed in plan 002 session (35ba44d).
- AKS 0.6.7 `count_of` vs autoscaler drift behavior still unverified (backlog).
