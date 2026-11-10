# Stamp catalog → Cilium caller policies

Inside an environment the AVNM mesh opens layer 3 between every stamp, so
*who may call whom* is enforced in-cluster. Each stamp's node subnets are
unique (`node_subnet_prefixes` output of `modules/aks-spoke`), which makes
"traffic from stamp X" expressible as `fromCIDR` in a
`CiliumClusterwideNetworkPolicy` (`network_policy = "cilium"`).

`stamps.json` is the allow-list: for every target stamp, the stamps allowed
to reach pods it labels `platform.demo/callable: "true"` (everything else
from the mesh is dropped by the generated default-deny for that label).

```json
{
  "dev": {
    "demo-dev-eus2": { "allow_from": ["demo-dev-wus3"] },
    "demo-dev-wus3": { "allow_from": ["demo-dev-eus2"] }
  }
}
```

Generate the manifests (reads each stamp's outputs from state; needs
`source .env`):

```bash
scripts/gen-cilium-caller-policies.sh dev            # -> catalog/out/dev/<stamp-id>.yaml
kubectl --kubeconfig ~/.kube/aks-demo-dev-eus2.yaml apply -f catalog/out/dev/demo-dev-eus2.yaml
```

Offline (CI, tests) pass a prepared `stamp-id → node subnets` file instead:
`scripts/gen-cilium-caller-policies.sh dev --subnets catalog/testdata/dev-subnets.json`.
`catalog/out/` is gitignored; the policies are derived data.
