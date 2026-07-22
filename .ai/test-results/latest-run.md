# Latest test run

- **Date**: 2026-07-21
- **Suite**: cross-region hub transit e2e (plan 002)
- **Result**: ✅ PASS

## What ran

1. Offline: `terragrunt run --all -- validate` across all 8 units - pass.
2. Live applies: dev/westus3 (18 res) + dev/eastus2 (19 res) + transit
   layer (12+2/14+2 res) + RBAC fixes (2+2 res) - all `Apply complete`, 0 destroyed.
3. E2E: `hello-eus2` (nginx + internal LB, annotation
   `azure-load-balancer-internal: "true"`) deployed to eus2 cluster; curl pod
   (`curlimages/curl`, tolerations for CriticalAddonsOnly + spot) in wus3:

```
ILB_IP=10.21.0.5
--- curl output from westus3 pod ---
hello from aks-demo-dev-eus2 (spoke 10.21.0.0/16) via hub transit
CURL_EXIT_OK
```

Proof of transit: spokes have no direct peering; only possible path is
node UDR → FW1 (10.10.0.4) → hub↔hub peering → FW2 (10.20.0.4) → spoke2.
Both firewalls confirmed `Succeeded` at exactly the predicted .4 addresses.

## Re-run

```bash
bash /path/to/xregion-test.sh   # see snapshot file for inline copy
```
(Script lives in .ai/test-results/2026-07-21-aks-e2e.md; needs both
kubeconfigs and the hello-eus2 workload deployed.)
