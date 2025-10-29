---
layout: doc
---

# CLI クイックリファレンス

## [`tailscale up`](https://tailscale.com/kb/1080/cli#up)

```sh
tailscale up [flags]
```

Tailscale ネットワークに自身のデバイスを接続します。

- `--ssh`: Tailscale SSH を有効にします
- `--force-reauth`: 鍵の再認証を行います
- `--exit-node=<node>`: 指定したノードを Exit Node として使用します

## [`tailscale down`](https://tailscale.com/kb/1080/cli#down)

```sh
tailscale down
```

Tailscale ネットワークから自身のデバイスを切断します．

- `--reason=<description>` : 切断の理由を指定します．切断時に Admin Console や m1sk9 の Discord サーバに通知されます．

## [`tailscale exit-node`](https://tailscale.com/kb/1080/cli#exit-node)

Exit Node の情報を表示します．

```sh
tailscale exit-node <subcommands>
```

- `list`: 利用可能な Exit Node の一覧を表示します
- `suggest`: 推奨される Exit Node を表示します

## [`tailscale file`](https://tailscale.com/kb/1080/cli#file)

Taildrop を使用してファイルを送受信します．

```sh
# ファイルをコピー
tailscale file cp <files...> <target>:
# ファイルを取得
tailscale file get <target-directory>
```

## [`tailscale netcheck`](https://tailscale.com/kb/1080/cli#file)

物理ネットワークの状態に関するレポートを取得します．

```sh
tailscale netcheck
```
