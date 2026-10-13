# k8s

Manifests for the k3s cluster (s2: server, s1: agent). ArgoCD syncs everything under [`apps/`](./apps) from `main`.

## Layout

- [`bootstrap/root.yaml`](./bootstrap/root.yaml): `AppProject` and `ApplicationSet`. Applied once by hand; this is not part of CD.
- `apps/<name>/`: one directory is one ArgoCD Application and one namespace named `<name>`.
  - Each directory is a Helm chart. Upstream charts go in `Chart.yaml` `dependencies` (umbrella chart) with overrides in `values.yaml`; in-house workloads put their manifests in `templates/`.

Adding a service is adding a directory.

## Placement

Nodes carry a `m1sk9.dev/pool` label, set with `node-label` in the k3s config so that it survives rebuilding a node. The `node-role.kubernetes.io/` prefix is avoided because kubelet may not set it on itself.

| Node | Label | Workloads |
| --- | --- | --- |
| s1 | `m1sk9.dev/pool=apps` | Pythia, babyrite, chime, PdfDing, honeypot |
| s2 | `m1sk9.dev/pool=observability` | Grafana, Prometheus, Loki |

- Pin workloads with `nodeSelector` on that label.
- Metrics and log collectors are DaemonSets without a `nodeSelector` so they run on both nodes.
- ArgoCD is pinned to the k3s server (s2) with `node-role.kubernetes.io/control-plane`, which k3s sets itself, so that it stays off s1 while its OS is reinstalled.
- No taints are used.

## Storage

PVCs use the k3s default `local-path` provisioner, so data lives on the node's disk and a PVC stays with the node its Pod is pinned to. The backup target is decided in the restic work (#474).

## Access

- Prometheus, Loki and other components that serve only the cluster are reachable over Tailscale only.
- ArgoCD and Grafana are used by other administrators, so they go through Cloudflare Tunnel with Access (GitHub IdP), and each app enforces its own GitHub OAuth roles as well.
