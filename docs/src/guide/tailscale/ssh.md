---
layout: doc
---

# Taiscale SSH を使用してデバイスに SSH する

::: tip

公式ドキュメントも同時に参照ください．

https://tailscale.com/kb/1216/tailscale-ssh-console

:::

::: warning

infra.m1sk9.dev のサーバへ SSH 接続できるのは一部のメンバーのみです

:::

## 接続する方法

::: warning 使用前の確認

- **infra.m1sk9.dev の Tailscale ネットワーク (Tailnet) にデバイスを設定していること**
  - 参加していない場合は m1sk9 に連絡してください．
- 接続先のサーバにユーザーを追加してもらっていること
  - 追加されていない場合は m1sk9 に連絡してください．

:::

Tailscale SSH を使用して接続するには，以下のコマンドを実行します．

```sh
tailscale ssh <username>@<hostname>
```

また `ssh` コマンドも使用できます．

```sh
ssh <username>@<hostname>
```

サーバに関する情報は各サーバガイドを参照してください．
