# tailscale

Tailnet のポリシーファイル (ACL) を [`policy.hujson`](./policy.hujson) で管理します．

サーバー (s1 / s2) は Tailnet の中からしか到達できません．このファイルで次のアクセスを制御しています．

- サーバーへのアクセスと Tailscale SSH を許可するユーザー・タグ (CI の `tag:ci` を含む)
- k3s のノード間通信 (apiserver，kubelet，flannel)
- Prometheus (s2) から s1 の node-exporter へのスクレイプ
- NextDNS の割り当て

## 適用

[`tailscale/gitops-acl-action`](https://tailscale.com/docs/integrations/github/gitops) で同期します．

- **CI** (pull request): `action: test` でポリシーを検証します．Tailnet には反映しません．
- **CD** (`main` への push): `action: apply` で検証し，成功すれば Tailnet に反映します．

NextDNS のプロファイル ID は平文でコミットしていません．`${NEXTDNS_PROFILE_ID}` をプレースホルダとして書いておき，Action に渡す前に `envsubst` でシークレットの値に置き換えます．置き換え後のファイル (`policy.rendered.hujson`) は git-ignore しています．

## GitHub Secrets

| Secret | 用途 |
|---|---|
| `TS_OAUTH_CLIENT_ID_ACL` | OAuth クライアント ID (スコープ: `Policy File` の Read + Write) |
| `TS_OAUTH_SECRET_ACL` | 上記クライアントのシークレット |
| `TS_TAILNET` | Tailnet 名 (`tailscale status --json` の `CurrentTailnet.Name`) |
| `NEXTDNS_PROFILE_ID` | ポリシーの `nodeAttrs` で使う NextDNS プロファイル ID |

Ansible の CI/CD が使う `TS_OAUTH_CLIENT_ID` / `TS_OAUTH_SECRET` とは別のクライアントです．あちらは `auth_keys` スコープのみで，ポリシーファイルを読み書きできません．

## 初回セットアップ

1. Tailscale の管理画面の **Settings → OAuth clients** で，**Policy File** スコープ (Read と Write の両方) を持つクライアントを作成します．
2. 上記の Secret を登録します．シェル履歴に残さないよう，値は対話プロンプトで入力します．

   ```fish
   gh secret set TS_OAUTH_CLIENT_ID_ACL --repo m1sk9/infra
   gh secret set TS_OAUTH_SECRET_ACL --repo m1sk9/infra
   gh secret set TS_TAILNET --repo m1sk9/infra
   gh secret set NEXTDNS_PROFILE_ID --repo m1sk9/infra
   ```

3. `policy.hujson` を変更する PR を作成し，`tailscale-acl-test` ジョブが通ることを確認してから merge します．
