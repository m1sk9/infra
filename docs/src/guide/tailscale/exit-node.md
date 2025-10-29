---
layout: doc
---

# Exit Node を使用する

::: tip

公式ドキュメントも同時に参照ください．

https://tailscale.com/kb/1103/exit-nodes

:::

::: danger 定期再起動について

infra.m1sk9.dev でホストされているサーバは定期再起動が設けられています．

再起動中は，Exit Node が非常に不安定になりインターネットから切断される可能性があります．

安定した家庭用インターネット接続を利用できる場合は，Exit Node を無効にしてデバイスをご利用ください．

:::

<iframe width="560" height="315" src="https://www.youtube.com/embed/Ad7D2pkFNdA?si=KxPRy1NPMbDAXjAR" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## Exit Node とは

Tailscale のネットワーク (Tailnet) 内で発生する全トラフィックを特定のデバイス経由でインターネットに送信する機能です．

通常，Tailscale はデバイス同士の通信だけを中継しますが， Exit Node を設定することで **自分の端末 → Exit Node → 公共インターネット** というルーティングを設定することができるようになります．

Exit Node を使用していない状態では， Tailscale ネットワークに接続していても公共のインターネットへのアクセスは，直接インターネットに接続されているネットワーク経由で行われます．

以下のような状況では Tailscale Exit Node の利用が有効です．

- 信頼できない Free Wi-Fi 環境のカフェにいる場合
- 地理的に制限されたコンテンツにアクセスしたい場合

![](https://tailscale.com/_next/static/media/exit-node-01.0573451b.svg)

![](https://tailscale.com/_next/static/media/exit-node-02.0e4f672e.svg)

## infra.m1sk9.dev での Exit Node について

infra.m1sk9.dev では現在以下のサーバーが Exit Node として利用可能です:

- dev-m1sk9-s1

## Exit Node の設定方法

::: warning 使用前の確認

- **infra.m1sk9.dev の Tailscale ネットワーク (Tailnet) にデバイスを設定していること**
  - 参加していない場合は m1sk9 に連絡してください．
- Exit Node を使用するデバイスが Tailscale v1.20 以降であること

:::

::: danger "Run exit node" は選択しないでください

infra.m1sk9.dev ではメンバーの全デバイスが Exit Node に設定できるようになっています．

Tailscale メニューの "Run exit node" オプションを有効にすると， 他のメンバーがあなたのデバイスを Exit Node として使用できるようになってしまい，予期せぬトラフィックが発生する可能性があります．

Exit Node を設定する際は "Run exit node" オプションは選択しないよう注意してください．

:::

::: details Android

1. Tailscale アプリを開きます
2. Exit Node セクションに移動します
3. [Exit Node 対応デバイス](#infra-m1sk9-dev-での-exit-node-について) を選択します

:::

::: details iOS

1. Tailscale アプリを開きます
2. トップページの上部にある [Exit Node 対応デバイス](#infra-m1sk9-dev-での-exit-node-について) を選択します

:::

::: details Linux

1. 以下のコマンドを実行します

```sh
tailscale status
```

2. Exit Node に設定したいデバイスの IP アドレスまたはホスト名を確認します. (Exit Node 対応デバイスには `status` 欄に "exit node" と表示されています)

```sh
xxx   dev-m1sk9-s1    tagged-devices  linux    active; exit node; direct xxxx
```

3. 以下のコマンドを実行して Exit Node を設定します

```sh
sudo tailscale set --exit-node=<IPアドレスまたはホスト名>
```

:::

::: details macOS

1. メニューバーにある Tailscale アイコンをクリックします
2. "Exit Nodes" から [Exit Node 対応デバイス](#infra-m1sk9-dev-での-exit-node-について) を選択します

:::

## ローカルネットワークへのアクセス

Exit Node に接続しているデバイスはローカルネットワークにアクセス出来なくなります．

Exit Node 有効時にローカルネットワークにアクセスしたい場合は，各 Tailscale クライアントの Exit Node セクションから有効化できます．

また `tailscale up` または `tailscale set` コマンドに `--exit-node-allow-lan-access` オプションを追加することでも有効化できます．
