# infra-docs: リソースの使い方

k3s クラスタで動かしている管理用ツールの簡単な使い方です．詳しい使い方は各ツールの公式ドキュメントを参照してください．

| ツール | URL | 用途 |
|---|---|---|
| ArgoCD | [argocd.m1sk9.dev](https://argocd.m1sk9.dev) | k8s へのデプロイ状況の確認 |
| Grafana | [grafana.m1sk9.dev](https://grafana.m1sk9.dev) | メトリクスとログの確認 |

## ログイン

どちらも Cloudflare Access で保護しており，ログインは 2 段階です．

1. URL を開くと Cloudflare Access のログイン画面が表示されるので，GitHub でログインします．
2. ツールのログイン画面で **Cloudflare Access** を選びます．Cloudflare Access がそのまま OIDC プロバイダーになっているため，追加の入力なしでログインできます．

アクセスを許可するメールアドレスは [`terraform/cloudflare_access.tf`](../terraform/cloudflare_access.tf) の Access policy で管理しています．権限はツールごとに次のように決まります．

| ツール | 権限の設定場所 | 現在の設定 |
|---|---|---|
| ArgoCD | [`k8s/apps/argocd/values.yaml`](../k8s/apps/argocd/values.yaml) の `rbac.policy.csv` | `me@m1sk9.dev` が admin．それ以外は権限なし |
| Grafana | [`k8s/apps/monitoring/values.yaml`](../k8s/apps/monitoring/values.yaml) の `role_attribute_path` | `me@m1sk9.dev` が GrafanaAdmin．それ以外は Viewer |

管理者を追加するときは，Access policy とツールの権限設定の両方を変更します．

## ArgoCD

ArgoCD は `main` の `k8s/apps/*` をクラスタに同期しています (仕組みは [`DEPLOYMENT.md`](./DEPLOYMENT.md) を参照してください)

### 同期状態を確認する

トップの Applications 画面に，`k8s/apps/` のディレクトリごとに Application が並びます．各 Application には 2 つの状態が表示されます．

- **Sync Status**: Git とクラスタの差分です．`Synced` なら `main` の内容がそのまま適用されています．`OutOfSync` なら差分があります．
- **Health Status**: リソースの状態です．`Healthy` なら正常です．`Progressing` は起動中，`Degraded` は Pod の起動失敗などの異常を表します．

Application を開くと，Deployment・Pod・ConfigMap などのリソースがツリーで表示されます．Pod を選ぶと **Logs** タブでログを，**Events** タブで k8s のイベントを確認できます．

### 手動で同期する

merge 後は自動で同期されますが，すぐに反映したい場合は Application の画面で **Refresh** (Git の再取得) や **Sync** を押します．

自動同期は `selfHeal` が有効なので，ArgoCD の画面やクラスタ上で設定を書き換えても Git の状態に戻されます．変更は必ず PR で行ってください．

### 公式ドキュメント

- [Argo CD - Declarative GitOps CD for Kubernetes](https://argo-cd.readthedocs.io/en/stable/)
- [Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Application Sync Status / Health](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)

## Grafana

Grafana では Prometheus のメトリクスと Loki のログを確認できます．どちらもデータソースとして登録済みです．

- **Prometheus**: ノード (s1 / s2) と k8s のメトリクスです．保持期間は 15 日です．
- **Loki**: すべての Pod のログです．Alloy が両ノードから収集しています．

### ダッシュボードを見る

左メニューの **Dashboards** に，kube-prometheus-stack に同梱されているダッシュボードが入っています．よく使うものは次のとおりです．

- **Node Exporter / Nodes**: ノードごとの CPU・メモリ・ディスク・ネットワーク．上部の `instance` で `s1` / `s2` を切り替えます．
- **Kubernetes / Compute Resources / Namespace (Pods)**: namespace ごとの Pod のリソース使用量．

### ダッシュボードとアラートを変更する

自作のダッシュボードとアラートの設定は，`k8s/apps/monitoring/` で管理しています．プロビジョニングされているため，Grafana の UI では保存も削除もできません．変更は PR で行います．

- **ダッシュボード**: UI で作り込み，**Export** → **Export as code** → **Classic** で JSON を書き出して，`dashboards/<フォルダ>/<名前>.json` を置き換えます．Loki と Prometheus の Datasource は，Export の **Export for sharing externally** を切ったまま (uid 参照のまま) にします．新しいダッシュボードは，ファイルを追加するだけで読み込まれ，置いたディレクトリ名 (`bots`，`infrastructure`) が Grafana のフォルダ名になります．新しいフォルダが必要なときは，ディレクトリを追加します．
- **アラートルール**: `alerting/rules.yaml` を編集します．UI でルールを作って **Export** で YAML を取り出し，貼り付けると楽です．通知したいルールには `notify: discord` ラベルを付けます．
- **Contact point / Notification policy**: `alerting/contactpoints.yaml` と `alerting/policies.yaml` を編集します．webhook URL などの秘密情報はファイルに書かず，`grafana-discord` Secret から環境変数で渡します．

merge 後に ArgoCD が同期し，sidecar が数十秒で Grafana に反映します．

### ログを検索する

左メニューの **Explore** でデータソースに **Loki** を選び，LogQL でログを検索します．ログには `namespace`，`pod`，`container`，`node` のラベルが付いています．

```logql
# chime のログ
{namespace="chime"}

# s1 で動いている Pod のエラーログ
{node="dev-m1sk9-s1"} |= "error"
```

### Claude Code から使う (Grafana MCP)

リポジトリの `.mcp.json` に [Grafana MCP サーバー](https://github.com/grafana/mcp-grafana) を登録しています．Claude Code からダッシュボードの参照やメトリクス・ログの検索ができます．`--disable-write` を付けているため読み取り専用です．

MCP サーバーは GitHub ログインを通れません．そのため，次の 2 つの token で認証します．

- **Cloudflare Access の service token**: Access を通過するためのものです．Terraform が発行します (`grafana_mcp_access_*`)．
- **Grafana の service account token**: Grafana の API を呼ぶためのものです．Grafana の UI で発行します．

初回は次の手順で設定します．

1. Grafana の **Administration > Users and access > Service accounts** で，Role を **Viewer** にした service account を作り，token を発行します．
2. `terraform/` で service token を取得します．

   ```fish
   terraform output -raw grafana_mcp_access_client_id
   terraform output -raw grafana_mcp_access_client_secret
   ```

3. リポジトリ直下に `mise.local.toml` を作り，取得した値を書きます．このファイルは git-ignore されています．

   ```toml
   [env]
   GRAFANA_SERVICE_ACCOUNT_TOKEN = "glsa_..."
   GRAFANA_MCP_ACCESS_CLIENT_ID = "..."
   GRAFANA_MCP_ACCESS_CLIENT_SECRET = "..."
   ```

4. リポジトリのディレクトリで Claude Code を起動し直します．`/mcp` で `grafana` が connected になっていれば完了です．

環境変数は Claude Code の起動時に読み込まれます．値を変えた場合は Claude Code を起動し直してください．

### 公式ドキュメント

- [Grafana documentation](https://grafana.com/docs/grafana/latest/)
- [Explore](https://grafana.com/docs/grafana/latest/explore/)
- [LogQL: Log query language](https://grafana.com/docs/loki/latest/query/)
- [Querying Prometheus (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
