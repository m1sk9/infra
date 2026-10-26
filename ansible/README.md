# ansible

s1 / s2 のホストの設定を Ansible で管理します．ワークロードは k3s ([`k8s/`](../k8s)) で動かしており，ここで扱うのはホストの設定だけです．

- restic による Cloudflare R2 へのバックアップ
- Better Stack への heartbeat 送信
- k3s のセットアップ (s2: server，s1: agent) と ArgoCD の初期導入

ホストには Tailnet の MagicDNS 名で接続します．シークレットは `ansible-vault` で暗号化しています．

## 前提

- `ansible-core` は [mise](https://mise.jdx.dev/) でインストールします ([`mise.toml`](../mise.toml))．`mise install` を実行すると，uv をバックエンドに `pipx:ansible-core` が入ります．
- 操作するマシンが Tailnet に参加している必要があります．ホストには Tailnet の中からしか到達できません．
- vault のパスワードファイル `ansible/.vault_pass` を手元に置く必要があります (git-ignore 済み)．`ansible.cfg` が常にこのファイルを読むため，`--syntax-check` でもこのファイルがないと失敗します．

## 構成

```
ansible/
├── ansible.cfg
├── inventory/
│   ├── hosts.yml                # ホスト，k3s のグループ，ノードラベル
│   ├── group_vars/all/
│   │   ├── vars.yml             # 共通の変数．シークレットは vault_ 変数を参照する
│   │   └── vault.yml            # ansible-vault で暗号化したシークレット
│   └── host_vars/
│       └── s2.yml               # s2 固有の変数 (bot の heartbeat，k3s のバックアップ対象)
├── roles/
│   ├── restic_backup/           # restic による週次バックアップ
│   ├── heartbeat/               # Better Stack への heartbeat 送信 (systemd timer)
│   ├── k3s_agent/               # s1 を k3s agent として参加させる
│   ├── k3s_node_labels/         # s2 のノードラベル
│   ├── k3s_disable_addons/      # s2 で traefik / servicelb を無効化
│   └── argocd_bootstrap/        # ArgoCD の初期導入 (一度だけ)
└── playbooks/
    ├── site.yml                 # 疎通確認
    ├── backup.yml               # s1 / s2 のバックアップ
    ├── monitoring.yml           # s1 / s2 の heartbeat
    ├── k8s.yml                  # s2 の k3s 設定と ArgoCD の初期導入 (手動)
    └── k8s-agent.yml            # s1 の k3s 参加 (手動)
```

## ホスト

| ホスト | MagicDNS 名 | 役割 |
|---|---|---|
| s1 | `dev-m1sk9-s1` | k3s agent (`m1sk9.dev/pool=apps`) |
| s2 | `dev-m1sk9-s2` | k3s server (`m1sk9.dev/pool=observability`) |

## 使い方

`ansible.cfg` の相対パスはカレントディレクトリを基準に解決されるため，`ansible/` に移動してから実行します．

```fish
cd ansible

# 疎通確認
ansible-playbook playbooks/site.yml

# 変更の確認 (plan 相当)
ansible-playbook playbooks/backup.yml --check --diff

# 適用
ansible-playbook playbooks/backup.yml
```

`backup.yml` と `monitoring.yml` は CD が自動で適用します (「CI / CD」を参照)．手元で適用する必要があるのは `k8s.yml` と `k8s-agent.yml` だけです．

## シークレット (ansible-vault)

シークレットは [`inventory/group_vars/all/vault.yml`](./inventory/group_vars/all/vault.yml) に `vault_` 接頭辞付きで格納します．[`vars.yml`](./inventory/group_vars/all/vars.yml) の変数がそれを参照するので，playbook や role がシークレットを直接読むことはありません．

```fish
ansible-vault edit inventory/group_vars/all/vault.yml
ansible-vault view inventory/group_vars/all/vault.yml
```

vault のパスワードは `.vault_pass`，GitHub Secret の `ANSIBLE_VAULT_PASSWORD`，パスワードマネージャーの 3 箇所に同じ値で保管しています．失うと暗号化したシークレットを復元できません．

| Vault キー | 内容 |
|---|---|
| `vault_become_password` | `become` のパスワード |
| `vault_restic_password` | restic リポジトリのパスワード |
| `vault_r2_access_key_id` / `vault_r2_secret_access_key` | R2 の S3 API トークン (バックアップ用バケットへの Object Read & Write) |
| `vault_heartbeat_url_*` | Better Stack の heartbeat URL (Terraform の出力からコピー) |
| `vault_k3s_token` | k3s の join トークン |

R2 の S3 API トークンは Terraform では発行できないため，手作業で発行して vault に格納しています．

## バックアップ

restic で Cloudflare R2 のバケットにバックアップします．暗号化・重複排除・世代管理は restic が行います．`restic_backup` role は次のことを行います．

- バージョンを固定した restic をインストールする
- バックアップスクリプトを配置する
- systemd timer で週に 1 回実行する

s1 と s2 は同じリポジトリを共有しています．各スナップショットにはホスト名を `--host` とタグの両方で付けます．`restic forget --prune` が排他ロックを取るため，s2 の実行時刻は s1 より 30 分遅らせています (s1: 金曜 03:00，s2: 金曜 03:30)．

### バックアップ対象

バックアップ対象は変数 `backup_targets` で宣言し，role 自体はデータに依存しません．**対象を増やすときは，role ではなくエントリを追加します．**

```yaml
backup_targets:
  - name: <tag>            # restic の --tag
    sqlite_dbs:            # 省略可: `sqlite3 .backup` でオンラインスナップショットを取る
      - /path/to/foo.db
    paths:                 # 省略可: そのまま restic に渡すファイル・ディレクトリ
      - /path/to/dir
    pre_commands:          # 省略可: バックアップ前に実行するコマンド (出力先は ${snap_base}/<name>/)
      - "..."
```

現在の対象は次のとおりです．s1 は k3s に移行してホスト上に残すデータがなくなったため，対象はありません．

| ホスト | 対象 | 内容 |
|---|---|---|
| s2 | `k3s` | k3s のデータストア (SQLite)，join トークン，CA，設定 |
| s2 | `sealed-secrets-keys` | Sealed Secrets の秘密鍵．失うと Git 上の SealedSecret をすべて復号できなくなる |

これ以外のクラスタの状態は ArgoCD が Git から再構築します．

### 通知

成功時は `ExecStartPost` で heartbeat に ping を送ります．失敗時は `OnFailure=` で journal の末尾を `<url>/fail` に送ります．`backup_heartbeat_url` を空にするとどちらも無効になります．

### リストア

ホスト上で，配置済みの env ファイル (リポジトリの URL と認証情報) を読み込んでから restic を実行します．

```fish
# スナップショットの一覧
sudo bash -c 'set -a; . /etc/restic/infra-backup.env; restic snapshots --host s2'

# 最新の k3s スナップショットを復元
sudo bash -c 'set -a; . /etc/restic/infra-backup.env; restic restore latest --host s2 --tag k3s --target /tmp/restore'
```

## 監視 (heartbeat)

ホストには外部から到達できないため，監視は push 型にしています．`heartbeat` role が systemd timer を配置して Better Stack に ping を送り，ping が途絶えると Better Stack がインシデントを起票します．heartbeat とステータスページ ([status.m1sk9.dev](https://status.m1sk9.dev)) は Terraform で定義しています．

送信対象は変数 `heartbeat_targets` で宣言します．**監視を増やすときは，エントリを追加し，対応する `betteruptime_heartbeat` リソースを Terraform に追加します．**

```yaml
heartbeat_targets:
  - name: <unit 名>         # unit・スクリプト・env ファイルの名前に使う
    url: "{{ vault_heartbeat_url_<name> }}"
    oncalendar: "*:0/3"     # systemd の schedule
    check_command: "..."    # 省略可: 0 以外で終了すると <url>/fail に送る
```

| ホスト | 対象 | 何を確認しているか |
|---|---|---|
| s1 | `s1-host` | ping が届くこと自体を確認する．ただし確認できるのは「s1 からインターネットに出られる」ことまでで，回線障害でも同じように落ちる |
| s2 | `chime` | Deployment の `availableReplicas` が 1 であること．readiness probe で `chime health` を実行しているので，アプリの動作まで確認できる |
| s2 | `babyrite`，`honeypot`，`pythia` | Deployment の `availableReplicas` が 1 であること．Pod が動いていることしか確認できず，Discord gateway の切断は検知できない |

k3s 上の bot の確認は `k3s kubectl` を実行できる s2 から送っています．Pod が Pending (s1 停止) ・CrashLoop・readiness 失敗のどれでも，s2 が停止しても ping が途絶えます．

ArgoCD と Grafana は，外部から HTTP で確認する monitor を Terraform で定義しています ([`terraform/betteruptime_monitor.tf`](../terraform/betteruptime_monitor.tf))．Cloudflare Access の service token を付けて health エンドポイントを確認するため，Pod までの経路全体が対象です．ホストへの heartbeat とは別の仕組みで，Ansible の設定は不要です．

heartbeat の URL は Terraform が発行しますが，Ansible は Terraform の state を読めないため，手作業で vault にコピーします．**URL を知っていれば誰でも正常を報告できるため，シークレットとして扱います．**

```fish
cd terraform
terraform output -raw heartbeat_url_s1_host
cd ../ansible
ansible-vault edit inventory/group_vars/all/vault.yml
```

### Dashboard でしか設定できない項目

Better Stack の Free プランでは，ステータスページの **Advanced settings** を API から書き込めません．そのため以下は手作業で設定しており，Terraform では管理していません．

| 設定 | 値 |
|---|---|
| Status history → How many days to display? | 90 days |
| Look & feel → Minimum incident length | 0 より大きくする (単発の失敗を表示しないため) |
| Search engines → Hide from search engines | 有効 |
| Replace top navigation links | m1sk9.dev へのリンク |
| **Status page access → Published** | **有効 (無効だとページが公開されない) ** |

また，Personalization (design，theme，layout) は API から書き込めますが，PR を経ずに調整できるよう dashboard で設定しています．Terraform はこれらの値を変更しません．

## k3s

`k8s.yml` と `k8s-agent.yml` は CD に含めず，手動で適用します．

- **`k8s.yml` (s2) **: ノードラベルを付け，traefik / servicelb を無効化し，ArgoCD を初期導入します．
  - ノードラベルと無効化の設定は，`config.yaml.d/` の drop-in として書き込みます．
  - ArgoCD の初期導入は一度だけ行います．導入後は ArgoCD が `k8s/apps/argocd` を通じて自分自身を管理するため，2 回目以降の実行では何もしません．
- **`k8s-agent.yml` (s1) **: k3s のバイナリをチェックサムで検証してインストールし，s2 に join します．
  - node IP は `tailscale ip -4` から取得します．
  - join トークンは `vault_k3s_token` から読みます．

バージョンを上げるときの注意:

- **k3s**: agent (`k3s_agent` の `k3s_version`) を server より新しくしてはいけません．server を先に上げます．
- **Helm**: `argocd_bootstrap` の `helm_version` は [`mise.toml`](../mise.toml) の `helm` と揃えます．

## CI / CD

- **CI** ([`ci.yaml`](../.github/workflows/ci.yaml)，pull request): すべての playbook に `--syntax-check` を実行します．続いて `backup.yml`，`monitoring.yml` を `--check --diff` で実行し，PR で変更内容を確認できるようにします．
- **CD** ([`cd.yaml`](../.github/workflows/cd.yaml)，`main` への push): Tailnet に参加してから，`backup.yml`，`monitoring.yml` を適用します．

runner は [Tailscale GitHub Action](https://tailscale.com/kb/1276/tailscale-github-action) で `tag:ci` のエフェメラルノードとして Tailnet に参加し，**Tailscale SSH** でホストに接続します．そのため長期間有効な SSH 鍵は GitHub に置いていません．SSH の認可は [`tailscale/policy.hujson`](../tailscale/policy.hujson) の `ssh` ルールで行います．

### GitHub Secrets

| Secret | 用途 |
|---|---|
| `ANSIBLE_VAULT_PASSWORD` | vault の復号 |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth クライアント ID (`auth_keys` スコープ，`tag:ci` を所有) |
| `TS_OAUTH_SECRET` | 上記クライアントのシークレット |

ホスト側では Tailscale SSH を有効にしておく必要があります (`sudo tailscale up --ssh`)．
