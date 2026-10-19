# infra

[![CI](https://github.com/m1sk9/infra/actions/workflows/ci.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/ci.yaml)
[![CD](https://github.com/m1sk9/infra/actions/workflows/cd.yaml/badge.svg)](https://github.com/m1sk9/infra/actions/workflows/cd.yaml)

Managed infrastructure for my open source projects.

デプロイガイドは [`docs/DEPLOYMENT.md`](./docs/DEPLOYMENT.md)，各インフラリソースの利用方法については [`docs/RESOURCE.md`](./docs/RESOURCE.md)，各マシンのスペックについては [`docs/machine/`](./docs/machine/) (`dev-m1sk9-s1.md` / `dev-m1sk9-s2.md`) を参照してください．

----

- [`ansible`](./ansible/README.md)
  - ホストの設定を Ansible で管理します．

- [`k8s`](./k8s/README.md)
  - k3s クラスタで動かすワークロードを Helm chart で管理します．
  - ArgoCD が `main` から同期します．

- [`tailscale`](./tailscale/README.md)
  - Tailnet のポリシーファイル (ACL) を管理します．

- [`terraform`](./terraform/README.md)
  - `m1sk9.dev` の Cloudflare リソース (DNS，Tunnel，Access，Workers，R2 など) の IaC 管理．
  - Better Stack の死活監視を Terraform で管理します．

<sub>
    Published under Zero-Clause BSD
    <br/>
    ® 2025 - 2026 m1sk9
</sub>
