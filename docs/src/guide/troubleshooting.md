---
layout: doc
---

# トラブルシューティング

#### Exit Node 接続中にインターネット回線が不安定になる

Exit Node 接続中は，すべてのトラフィックが特定デバイス経由でルーティングされます．

Exit Node が有効になっているサーバのインターネット接続が不安定になると，結果的にルーティング先のデバイスも不安定になります．

- Exit Node 先のデバイスに対して ping を実行して，応答が安定しているか確認してください

```sh
# Using Tailscale CLI
tailscale ping <exit-node-device>

# Using system ping command
ping <exit-node-ip-address>
```

- `netcheck` コマンドを使用して，[DERP](./faq.md#q-derp-サーバとは) との接続状態を確認してください

```sh
$ tailscale netcheck

Report:
	* Time: 2025-10-29T03:08:50.427068Z
	* UDP: true
# ----
	* DERP latency:
		- tok: 8.2ms   (Tokyo) # check this value
		- hkg: 61.6ms  (Hong Kong)
		- sin: 78.4ms  (Singapore)
# ----
```

#### 鍵の期限が切れた

Tailscale にはセキュリティ対策として，ユーザは各デバイスで定期的に再認証を行う必要があります． infra.m1sk9.dev では90日ごとに再認証が必要です．

再認証を行わない場合，キーは失効し当該デバイスは Tailscale ネットワークに接続できなくなります．

以下のコマンドを実行して，デバイスの認証を再認証してください．

```sh
tailscale up --force-reauth
```

::: tip Admin Console でのセッション期限について

Admin Console でのセッション期限は30日となっています．

:::

::: warning サーバの鍵について

予期せぬ障害を避けるため，Tailscale で接続されたサーバの鍵には有効期限が設定されていません．

サーバに対してはユーザによる再認証は不要ですが，自身のデバイスでは定期的に再認証が必要です．

:::

::: danger CLI での再認証時の注意

`tailscale up --force-reauth` を実行すると Tailscale の接続が切断される可能性があるため，接続が失われた場合に代替手段でログインできない状態では SSH や RDP 経由のリモート操作では実行することは避けてください．

:::
