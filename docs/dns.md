# DNS

Two hierarchies, both created by the platform layer and consumed by the
stamps: a **public** one for anything the Internet resolves, and a
**private** one for service discovery between stamps over the mesh.

## Public: one zone per cloud, one child per environment

Opt-in: set `TG_PUBLIC_DNS_PARENT_ZONE` (e.g. `azure.example.com`, a zone
under a domain you control) and the platform layer creates the hierarchy
below; leave it empty and no zones are created and stamps get no public
zone.

```
example.com                      your registrar / DNS provider (outside this repo)
├── azure.example.com            live/platform/dns  (connectivity subscription, rg-dns-public)
│   ├── dev.azure.example.com    delegated from the parent by NS records created here
│   ├── prod.azure.example.com
│   └── local.azure.example.com  optional external environment: a laptop cluster (Argo CD dev)
└── aws.example.com              e.g. another cloud's platform, same pattern
```

`modules/public-dns` creates the parent zone and one child zone per entry
in `platform.hcl: environments` **and** `external_environments`, and writes
the NS delegation record for each child into the parent. Adding an
environment therefore delegates its zone automatically. External
environments are clusters outside Azure (`local`, a laptop cluster such as
Rancher Desktop / k3s used to develop Argo CD app deployments, enabled with
`TG_ENABLE_LOCAL_CLUSTER=true`): they get a zone
and nothing else in Azure - no subscription, management group, hub or
stamp. A local cluster has no managed identity, so `live/platform/dns-principals`
gives each external environment a service principal `sp-dns-<env>` with DNS
Zone Contributor on its zone (+ Reader on `rg-dns-public`) and a 24-month
client secret, read out of Terraform state by the manifests repo and never
committed anywhere ([identity.md](identity.md) §5). The zones are shared infrastructure that every
environment depends on, so they live in `live/platform` and are applied
once, before any environment - production-grade even while only dev
exists. Cost is ~$0.50 per zone per month plus queries.

**One manual step, once:** after the first apply, take the
`parent_name_servers` output and create NS records for the `azure` label
in your `example.com` zone at whichever provider hosts it (four NS
records; if the provider proxies traffic, e.g. Cloudflare, set them to DNS
only):

```bash
cd live/platform/dns && terragrunt output parent_name_servers
```

Until that delegation exists the Azure zones answer only when queried
directly. Nothing in Azure needs to change when it is added.

Stamps receive their environment's zone ID through the `public_dns`
dependency and, with `enable_external_dns_identity`, the external-dns
identity gets DNS Zone Contributor on `<env>.azure.example.com` (and
Reader on `rg-dns-public`); `enable_cert_manager_identity` gives cert-manager
its own identity with DNS Zone Contributor on the same zone for DNS-01
challenges (`identity.md` §4; one identity per component). Public records are therefore published by
external-dns from inside each cluster - for example
`api.dev.azure.example.com` for an ingress annotated in the dev stamp.
Names under a stamp are a convention, not a zone: with two stamps in one
environment, use host labels that include the region or stamp id.

Settings in `live/platform/platform.hcl`:

| Setting | Default | Meaning |
|---|---|---|
| `enable_public_dns` | `true` when `TG_PUBLIC_DNS_PARENT_ZONE` is set | create the hierarchy (false = no zones, stamps get no public zone) |
| `public_dns_parent_zone` | `$TG_PUBLIC_DNS_PARENT_ZONE` | the per-cloud parent zone, e.g. `azure.example.com` |
| `external_environments` | `["local"]` when `TG_ENABLE_LOCAL_CLUSTER=true`, else `[]` | environments outside Azure: a zone plus a zone-scoped service principal |
| `dns_principal_secret_days` | `730` | client-secret lifetime for those principals (portal maximum) |

## Private: svc.<env>.platform.internal

`enable_private_dns` in `env.hcl` creates `svc.<env>.platform.internal`
(`modules/platform-network`, `rg-dns-platform`); hubs and stamps link
their own VNets to it, and the same external-dns identity gets Private DNS
Zone Contributor on it. Details in
[network-platform.md](network-platform.md) ("Service discovery"). The hub
DNS Private Resolver (`enable_dns_resolver`) is only needed for clients
outside Azure.

## external-dns in a stamp

One deployment per cluster can manage both zones (Azure public provider
with `--domain-filter=<env>.azure.example.com`, Azure private DNS
provider with `--domain-filter=svc.<env>.platform.internal`), both using
the stamp's workload identity: client ID from the `external_dns_client_id`
output, service account `external-dns/external-dns`
(`external_dns_service_account`). Zone names are the stamp outputs
`public_dns_zone_name` and `private_dns_zone_name`.
