# terraform

`m1sk9.dev` の Cloudflare リソースと，Better Stack の死活監視を Terraform で管理します．

State は [HCP Terraform](https://app.terraform.io/) で管理しています (organization: `m1sk9-terraform-org`，workspace: `infra`)．

## 管理対象

| ファイル | 内容 |
|---|---|
| [`cloudflare_dns_record.tf`](./cloudflare_dns_record.tf) | DNS レコード (Proton Mail，GitHub Pages，Bluesky / Discord の検証など) |
| [`cloudflare_tunnel.tf`](./cloudflare_tunnel.tf) | k3s クラスタ向けの Cloudflare Tunnel (`argocd.m1sk9.dev`，`grafana.m1sk9.dev`) |
| [`cloudflare_access.tf`](./cloudflare_access.tf) | Zero Trust Access (GitHub IdP，ArgoCD / Grafana の Access と OIDC，monitor 用の service token) |
| [`cloudflare_worker.tf`](./cloudflare_worker.tf) | Workers とそのカスタムドメイン・ルート．スクリプト本体は [`workers/`](./workers) にあります |
| [`cloudflare_r2_bucket.tf`](./cloudflare_r2_bucket.tf) | R2 バケット (restic バックアップ用，ledger のアーカイブ用) |
| [`cloudflare_ruleset.tf`](./cloudflare_ruleset.tf) | WAF カスタムルール |
| [`cloudflare_zone_setting.tf`](./cloudflare_zone_setting.tf) | ゾーン設定 (SSL，HSTS，最小 TLS バージョンなど) |
| [`cloudflare_bot_management.tf`](./cloudflare_bot_management.tf) | Bot Fight Mode |
| [`cloudflare_web_analytics.tf`](./cloudflare_web_analytics.tf) | Web Analytics |
| [`betteruptime_heartbeat.tf`](./betteruptime_heartbeat.tf) | Better Stack の heartbeat |
| [`betteruptime_monitor.tf`](./betteruptime_monitor.tf) | Better Stack の HTTP monitor (ArgoCD，Grafana) |
| [`betteruptime_status_page.tf`](./betteruptime_status_page.tf) | ステータスページ ([status.m1sk9.dev](https://status.m1sk9.dev)) |

`m1sk9.dev` 本体 (ポートフォリオ) の Worker スクリプトは m1sk9.dev リポジトリから wrangler でデプロイしており，ここではルーティングだけを管理しています．

## 適用

GitHub Actions で自動適用されます．

- **CI** (pull request): `terraform fmt -check`，`tflint`，`terraform validate`，`terraform plan`
- **CD** (`main` への push): `terraform plan`，`terraform apply`

手元で確認する場合は，HCP Terraform にログインしたうえで実行します．

```fish
cd terraform
terraform init
terraform fmt -check -recursive
tflint
terraform validate
terraform plan
```

`variables.tf` の変数 (API トークンなど) は HCP Terraform の workspace に設定しています．

## 他ディレクトリとの受け渡し

Terraform が発行する値のうち，次のものは手作業で他のディレクトリへ渡しています．

- **heartbeat の URL** (`heartbeat_url_*`): Ansible の vault に格納します．詳細は [`ansible/README.md`](../ansible/README.md) を参照してください．
- **Tunnel トークン・OIDC クライアント** (`k8s_tunnel_token`，`*_oidc_*`): SealedSecret として [`k8s/apps/`](../k8s/apps) 配下に格納します．

```fish
terraform output -raw <output 名>
```
