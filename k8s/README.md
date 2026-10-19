# k8s

k3s クラスタ (server: s2，agent: s1) で動かすワークロードのマニフェストを管理します．ArgoCD が `main` の [`apps/`](./apps) 配下をすべて同期します．

## 構成

- [`bootstrap/root.yaml`](./bootstrap/root.yaml): `AppProject` と `ApplicationSet` です．最初に一度だけ適用するもので，CD には含めていません ([`ansible/`](../ansible/README.md#k3s) の `k8s.yml` が ArgoCD と一緒に導入します)．
- [`bootstrap/sealed-secrets-cert.pem`](./bootstrap/sealed-secrets-cert.pem): Sealed Secrets の公開鍵です．
- `apps/<name>/`: 1 ディレクトリが 1 つの ArgoCD Application になり，`<name>` という namespace にデプロイされます．同期は自動で，`prune` と `selfHeal` を有効にしています．

| アプリ | 内容 |
|---|---|
| `argocd` | ArgoCD 自身．導入後は自分自身をこのディレクトリから管理する |
| `sealed-secrets` | Sealed Secrets コントローラー |
| `cloudflared` | Cloudflare Tunnel (ArgoCD / Grafana の入口) |
| `monitoring` | kube-prometheus-stack (Prometheus，Grafana，node-exporter) |
| `loki` | ログの保存 |
| `alloy` | ログの収集 |
| `babyrite`，`chime`，`honeypot`，`pythia` | 自作の Discord bot |

## サービスの追加

サービスを追加するときは，`apps/` にディレクトリを追加します．各ディレクトリは Helm chart です．

- **外部の chart を使う場合**: umbrella chart にします．`Chart.yaml` の `dependencies` に chart を書き，上書きする値を `values.yaml` に書きます．`Chart.lock` はコミットし，`charts/` は git-ignore しています．
- **自作のワークロードの場合**: マニフェストを `templates/` に置きます．イメージは `deployment.yaml` の `image` に `<repository>:<tag>` の形で直接書き，Renovate が更新します．設定ファイル (`config.toml` など) はディレクトリ直下に置き，`.Files.Get` で ConfigMap に読み込みます．ConfigMap は `subPath` でマウントしており，更新しても Pod に反映されないため，Deployment に `checksum/config` アノテーションを付けて Pod を入れ替えます．

CI (pull request) では，各 chart に対して `helm dependency update`，`helm lint`，`helm template` を実行します．手元では次のように確認できます．

```fish
helm dependency update apps/<name>
helm lint apps/<name>
helm template <name> apps/<name> --namespace <name>
```

## シークレット

シークレットは Sealed Secrets で暗号化してから `templates/` にコミットします．スコープは strict (デフォルト) なので，namespace はアプリのディレクトリ名と一致させます．

```fish
kubectl create secret generic <secret 名> --namespace <name> \
  --from-literal=KEY=value --dry-run=client -o yaml \
  | kubeseal --cert bootstrap/sealed-secrets-cert.pem --format yaml \
  > apps/<name>/templates/sealedsecret.yaml
```

暗号化に使う秘密鍵はクラスタ内にしかなく，s2 のバックアップに含めています ([`ansible/README.md`](../ansible/README.md#バックアップ))．秘密鍵を失うと，Git 上の SealedSecret はすべて復号できなくなります．

## Grafana の設定

`apps/monitoring/` では，自作のダッシュボードとアラート関連の設定をすべてコードで管理しています．`templates/` が，ディレクトリ内のファイルを ConfigMap にして，Grafana の sidecar に読み込ませます．

| 置き場所 | 内容 | 読み込み |
|---|---|---|
| `dashboards/*.json` | 自作のダッシュボード (chime，cpu-cooling，honeypot，pythia) | `grafana_dashboard` ラベルの ConfigMap |
| `alerting/rules.yaml` | アラートルール | `grafana_alert` ラベルの ConfigMap |
| `alerting/contactpoints.yaml` | Contact point (`discord-alerts`) | 同上 |
| `alerting/policies.yaml` | Notification policy | 同上 |

管理しているダッシュボードは次のとおりです．

| ダッシュボード | uid | 管理 | データソース | 内容 |
|---|---|---|---|---|
| Chime / Polling | `chime-polling` | `dashboards/chime-polling.json` | Loki | chime のポーリング件数・失敗数・転送数，WARN / ERROR ログ |
| CPU Cooling (s1, s2) | `cpu-cooling-s1-s2` | `dashboards/cpu-cooling-s1-s2.json` | Prometheus | CPU 使用率，コア温度，thermal throttle，`temp_max` までの余裕 |
| HoneyPot / Detections | `honeypot-detections` | `dashboards/honeypot-detections.json` | Loki | 検知関連イベント，ログ量 (レベル別・モジュール別)，WARN / ERROR ログ |
| Pythia / LLM Usage | `pythia-llm` | `dashboards/pythia-llm.json` | Loki | クレジット消費，トークン数，応答レイテンシ，WARN / ERROR ログ |
| Kubernetes / ...，Node Exporter / ...，Prometheus / Overview，CoreDNS，Grafana Overview | chart が採番 | kube-prometheus-stack (chart 同梱) | Prometheus | k8s とノードの標準ダッシュボード |

- 同梱のダッシュボードは，`values.yaml` と chart のバージョンで決まります．このリポジトリに JSON は置きません．
- Contact point の webhook URL は `grafana-discord` Secret (`DISCORD_WEBHOOK_URL`) から環境変数で渡します．Secret の作り方は[シークレット](#シークレット)のとおりです．
- ルールは `notify: discord` ラベルを付けると Discord に通知されます．ラベルのないアラートは，policy の root (`empty`) に流れて通知されません．
- プロビジョニングされたリソースは UI で編集も削除もできません．変更は PR で行います．手順は [`docs/RESOURCE.md`](../docs/RESOURCE.md#grafana) にあります．
- Loki の Datasource uid は，ダッシュボードとルールが参照しているため `values.yaml` で固定しています．

## 配置

ノードには `m1sk9.dev/pool` ラベルを付けています．ラベルは k3s の設定の `node-label` で付けるので，ノードを作り直しても消えません．`node-role.kubernetes.io/` 接頭辞は，kubelet が自分自身に設定できない場合があるため使っていません．

| ノード | ラベル | ワークロード |
|---|---|---|
| s1 | `m1sk9.dev/pool=apps` | babyrite，chime，honeypot，pythia |
| s2 | `m1sk9.dev/pool=observability` | Prometheus，Grafana，Loki |

- ワークロードは，このラベルを使って `nodeSelector` で固定します．
- Discord bot は s1 に固定しています (preferred ではありません)．s1 が切り離されたまま生きていると，s2 に再スケジュールされた Pod が旧 Pod と並んで動いてしまうためです．同じ理由で `strategy: Recreate` にしています．同じトークンでログインした 2 つのインスタンスは，すべてのメッセージに二重に返信します．
- メトリクスとログの収集は DaemonSet で，`nodeSelector` を付けずに両ノードで動かします．
- ArgoCD と cloudflared は，k3s が自動で付ける `node-role.kubernetes.io/control-plane` で k3s server (s2) に固定します．s1 の OS を再インストールしている間も止まらないようにするためです．
- taint は使っていません．

## ストレージ

PVC には k3s デフォルトの `local-path` プロビジョナーを使います．データはノードのディスクに置かれ，PVC は Pod を固定したノードから動きません．

PVC はバックアップしていません．Prometheus と Loki のボリュームはメトリクスとログだけで，失っても収集し直せるためです．

## アクセス

- Prometheus や Loki など，クラスタ内でしか使わないコンポーネントには Tailscale 経由でのみアクセスできます．
- ArgoCD (`argocd.m1sk9.dev`) と Grafana (`grafana.m1sk9.dev`) は他の管理者も使います．そのため Cloudflare Tunnel を通し，Cloudflare Access (GitHub IdP) で保護しています．さらに各アプリ側でも GitHub OAuth によるロール制御を行っています．Tunnel と Access は [`terraform/`](../terraform/README.md) で管理しています．
