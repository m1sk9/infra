# infra-docs: デプロイガイド

k3s クラスタへのアプリケーションのデプロイ方法です．クラスタの構成や配置のルールは [`k8s/README.md`](../k8s/README.md) を参照してください．

## デプロイの流れ

k3s へのデプロイは ArgoCD が行います．手元から `kubectl apply` や `helm install` は実行しません．

1. `k8s/apps/<name>/` を追加・変更する PR を作成する
2. CI の `helm` ジョブ (`helm dependency update` / `helm lint` / `helm template`) が通ることを確認する
3. `main` に merge する
4. ArgoCD が `main` を検知して自動で同期する ([argocd.m1sk9.dev](https://argocd.m1sk9.dev) で確認できます)

ArgoCD の `ApplicationSet` が `k8s/apps/*` のディレクトリを 1 つずつ Application にします．Application 名と namespace はディレクトリ名になります．同期は `prune` と `selfHeal` が有効なので，クラスタ上で手作業で変更しても Git の状態に戻されます．

## サービスを追加する

サービスを追加するには `k8s/apps/` にディレクトリを追加します (各ディレクトリは Helm chart になっています)

```
k8s
├── apps
│   ├── alloy
│   ├── argocd
│   ├── babyrite
│   ├── chime
│   ├── cloudflared
│   ├── honeypot
│   ├── loki
│   ├── monitoring
│   ├── pythia
│   └── sealed-secrets
├── bootstrap
│   ├── root.yaml
│   └── sealed-secrets-cert.pem
└── README.md
```

### 自作のアプリケーション

自作のアプリケーションは，マニフェストを `templates/` に置きます．chime を例にすると次の構成です．

```
k8s/apps/chime
├── Chart.yaml
├── config.toml                 # アプリケーションの設定ファイル
├── values.yaml                 # イメージとタグ
└── templates
    ├── configmap.yaml          # config.toml を ConfigMap にする
    ├── deployment.yaml
    └── sealedsecret.yaml       # 環境変数で渡すシークレット
```

#### 1. `Chart.yaml` と `values.yaml` を書く

イメージは `values.yaml` の `image.repository` と `image.tag` に書きます．Renovate は `templates/` を読まないため，`values.yaml` に書いたイメージだけを検出して更新の PR を作ります．タグを二重に管理しないよう，`Chart.yaml` に `appVersion` は書きません．

```yaml
# Chart.yaml
apiVersion: v2
name: <name>
version: 0.1.0
```

```yaml
# values.yaml
image:
  repository: ghcr.io/m1sk9/<name>
  tag: "v1.0.0"
```

#### 2. 設定ファイルを ConfigMap にする

設定ファイルはディレクトリ直下に置き，`.Files.Get` で ConfigMap に読み込みます．

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <name>-config
data:
  config.toml: |
{{ .Files.Get "config.toml" | indent 4 }}
```

#### 3. Deployment を書く

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <name>
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: <name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <name>
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      nodeSelector:
        m1sk9.dev/pool: apps
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          envFrom:
            - secretRef:
                name: <name>-env
          volumeMounts:
            - name: config
              mountPath: /etc/<name>/config.toml
              subPath: config.toml
              readOnly: true
          resources:
            requests:
              cpu: 10m
              memory: 64Mi
            limits:
              memory: 512Mi
      volumes:
        - name: config
          configMap:
            name: <name>-config
```

既存のアプリケーションに合わせて，次の点を守ります．

- **`nodeSelector`**: `m1sk9.dev/pool` ラベルで配置先のノードを固定します．アプリケーションは `apps` (s1)，監視系は `observability` (s2) です．
- **`checksum/config`**: ConfigMap は `subPath` でマウントしており，更新しても Pod に反映されません．このアノテーションで設定の変更時に Pod を入れ替えます．
- **`strategy: Recreate`**: Discord bot など，同時に 2 つ動くと困るものに付けます．同じトークンでログインした 2 つのインスタンスは，すべてのメッセージに二重に返信します．
- **probe**: ヘルスチェック用のコマンドやエンドポイントがあれば `livenessProbe` / `readinessProbe` を設定します (chime の `chime health` など)

#### 4. シークレットを SealedSecret にする

シークレットは平文でコミットせず，Sealed Secrets で暗号化します．スコープは strict なので，`--namespace` には必ずディレクトリ名を指定します．

```fish
kubectl create secret generic <name>-env --namespace <name> \
  --from-literal=TOKEN=xxxx --dry-run=client -o yaml \
  | kubeseal --cert k8s/bootstrap/sealed-secrets-cert.pem --format yaml \
  > k8s/apps/<name>/templates/sealedsecret.yaml
```

`kubectl create secret` は `--dry-run=client` で YAML を出力するだけなので，クラスタに接続する必要はありません．

#### 5. 手元で確認する

CI と同じコマンドで確認できます．

```fish
helm dependency update k8s/apps/<name>
helm lint k8s/apps/<name>
helm template <name> k8s/apps/<name> --namespace <name>
```

### 外部の Helm chart を使うアプリケーション

外部の chart は umbrella chart として取り込みます．`Chart.yaml` の `dependencies` に chart を書き，上書きする値を `values.yaml` に書きます．

```yaml
# Chart.yaml
apiVersion: v2
name: <name>
version: 0.1.0
dependencies:
  - name: <chart>
    version: 1.2.3
    repository: https://example.com/charts
```

```yaml
# values.yaml (dependency 名をキーにして上書きする)
<chart>:
  nodeSelector:
    m1sk9.dev/pool: observability
```

`helm dependency update` で生成される `Chart.lock` はコミットします．`charts/` は git-ignore しています．

## サービスを更新する

イメージのバージョンは Renovate が `values.yaml` の `image.tag` を更新する PR を作ります．minor / patch は CI が通れば自動で merge されます．手で上げるときも `image.tag` を更新して PR を merge します．設定ファイル (`config.toml`) の変更も同じ流れで，`checksum/config` によって Pod が入れ替わります．

外部の chart は `Chart.yaml` の `version` を上げ，`helm dependency update` で `Chart.lock` を更新してからコミットします．

## 外部に公開する

クラスタ内のサービスを外部に公開する場合は，Cloudflare Tunnel を使います．Tunnel の設定は Terraform で管理しています．

1. [`terraform/cloudflare_tunnel.tf`](../terraform/cloudflare_tunnel.tf) の `ingress` に，ホスト名と Service の DNS 名 (`http://<service>.<namespace>.svc.cluster.local:<port>`) を追加する．最後の `http_status:404` より前に書きます．
2. 同じファイルに，Tunnel を向く `cloudflare_dns_record` を追加する．
3. 管理者向けの画面など，アクセスを制限したい場合は [`terraform/cloudflare_access.tf`](../terraform/cloudflare_access.tf) に Access の設定を追加する．

> [!WARNING]
> `*.api.m1sk9.dev` のような 2 階層のサブドメインは Universal SSL の対象外なので，Tunnel 経由で公開すると HTTPS が使えません．
