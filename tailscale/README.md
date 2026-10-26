# tailscale

Tailnet のポリシーファイル (ACL) を [`policy.hujson`](./policy.hujson) で管理します．

サーバー (s1 / s2) は Tailnet の中からしか到達できません．Tailnet のユーザーは owner (m1sk9) だけで，他のユーザーとのマシン共有もしていません．

ポリシーは明示的に許可したもの以外をすべて拒否します．このファイルで許可しているのは次の通信だけです．

- owner の端末から，サーバーへのアクセスと Tailscale SSH
- owner の端末から，Exit Node を経由したインターネット
- k3s のノード間通信 (apiserver，kubelet，flannel)
- Prometheus から各ノードの node-exporter へのスクレイプ

Exit Node の自動承認 (`autoApprovers`) は使っていません．Exit Node を広告したら，管理画面で手作業で承認します．

### DNS

NextDNS は管理画面の DNS ページで Global nameserver として設定しており，Tailscale の DNS を受け入れる端末すべてに効きます．ポリシーの `nodeAttrs` で端末ごとにプロファイルを変えることはできますが，端末を NextDNS から外すことはできません．

そのためサーバー (s1 / s2) は `--accept-dns=false` で登録し，Tailscale の DNS を使いません．k3s の CoreDNS が参照するホストの DNS に，NextDNS が入り込まないようにするためです．代わりに MagicDNS 名も引けなくなるので，s1 が join に使う `dev-m1sk9-s2` は，`k3s_agent` role が `/etc/hosts` に書き込みます．

### ポリシーで制御できないもの

- **Taildrop**: 同じユーザーの端末同士では ACL に関係なく使えます．無効にするには，管理画面の **General** で **Send Files** をオフにします．
- **Taildrive**: `nodeAttrs` に `drive:share` / `drive:access` を書かない限り使えません．現在は書いていないので無効です．

## タグ

タグはマシンではなく役割に付けます．1 台が複数の役割を持つ場合はタグを重ねます．各マシンに付けているタグは [`docs/machine/`](../docs/machine) に記載しています．

| タグ | 役割 | 許可される主な通信 |
|---|---|---|
| `tag:k3s` | k3s ノード共通 | 管理アクセスと Tailscale SSH の宛先，kubelet (10250/tcp) と flannel (8472/udp) |
| `tag:k3s-server` | k3s の control-plane | apiserver (6443/tcp) の宛先 |
| `tag:k3s-agent` | k3s の agent | (現状は固有の許可なし) |
| `tag:observability` | Prometheus を載せるノード | node-exporter (9100/tcp) のスクレイプ元 |

個人の端末 (laptop / mobile) にはタグを付けません．タグを付けるとユーザーの端末として扱われなくなり，鍵の期限切れが無効になり，Taildrop も使えなくなるためです．個人の端末は owner として扱い，Exit Node の利用も owner に限っています．

マシンにタグを付けるには，そのマシンで次を実行します (例は s2)．

```fish
sudo tailscale up --ssh --accept-dns=false --advertise-exit-node --advertise-tags=tag:k3s,tag:k3s-server,tag:observability
```

## 適用

[`tailscale/gitops-acl-action`](https://tailscale.com/docs/integrations/github/gitops) で同期します．

- **CI** (pull request): `action: test` でポリシーを検証します．Tailnet には反映しません．読み取り専用のクライアントを使います．
- **CD** (`main` への push): `action: apply` で検証し，成功すれば Tailnet に反映します．書き込み権限を持つクライアントは，`main` からしか使えない GitHub Environment `tailscale-acl` にだけ置いています．

ポリシーの `tests` / `sshTests` には，崩してはいけないアクセスの条件 (apiserver は server 宛てだけ，ノード同士は SSH できない，など) を書いています．どちらの段階でも Tailscale が評価し，1 つでも外れると反映されません．**grants や ssh を変えるときは，対応するテストも更新します．**

NextDNS のプロファイル ID は平文でコミットしていません．`${NEXTDNS_PROFILE_ID}` をプレースホルダとして書いておき，Action に渡す前に `envsubst` でシークレットの値に置き換えます．置き換え後のファイル (`policy.rendered.hujson`) は git-ignore しています．

## GitHub Secrets

| Secret | 置き場所 | 用途 |
|---|---|---|
| `TS_OAUTH_CLIENT_ID_ACL_READ` | Repository | CI 用の OAuth クライアント ID (スコープ: `policy_file:read`) |
| `TS_OAUTH_SECRET_ACL_READ` | Repository | 上記クライアントのシークレット |
| `TS_OAUTH_CLIENT_ID_ACL` | Environment `tailscale-acl` | CD 用の OAuth クライアント ID (スコープ: `policy_file`) |
| `TS_OAUTH_SECRET_ACL` | Environment `tailscale-acl` | 上記クライアントのシークレット |
| `TS_TAILNET` | Repository | Tailnet 名 (`tailscale status --json` の `CurrentTailnet.Name`) |
| `NEXTDNS_PROFILE_ID` | Repository | ポリシーの `nodeAttrs` で使う NextDNS プロファイル ID |

Pull request の workflow は，同じリポジトリのブランチ (Renovate を含む) から実行されると Repository の Secret を読めます．そのため書き込み権限のクライアントは Repository には置きません．

GitHub Actions の runner は Tailnet に参加しません．使う OAuth クライアントは上の 2 つ (API でポリシーを検証・反映するだけ) で，ノードを作る `auth_keys` スコープのクライアントはありません．

## 初回セットアップ

1. Tailscale の管理画面の **Settings → Trust credentials** で OAuth クライアントを 2 つ作成します．
   - CI 用: `policy_file:read` (依存する `devices:core:read` と `devices:posture_attributes:read` も付与)
   - CD 用: `policy_file` (同上)
2. GitHub の Environment `tailscale-acl` を，デプロイ元ブランチを `main` に限定して作成します．
3. Secret を登録します．シェル履歴に残さないよう，値は対話プロンプトで入力します．

   ```fish
   gh secret set TS_OAUTH_CLIENT_ID_ACL_READ --repo m1sk9/infra
   gh secret set TS_OAUTH_SECRET_ACL_READ --repo m1sk9/infra
   gh secret set TS_OAUTH_CLIENT_ID_ACL --repo m1sk9/infra --env tailscale-acl
   gh secret set TS_OAUTH_SECRET_ACL --repo m1sk9/infra --env tailscale-acl
   gh secret set TS_TAILNET --repo m1sk9/infra
   gh secret set NEXTDNS_PROFILE_ID --repo m1sk9/infra
   ```

4. `policy.hujson` を変更する PR を作成し，`tailscale-acl-test` ジョブが通ることを確認してから merge します．
