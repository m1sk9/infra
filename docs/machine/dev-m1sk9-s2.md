# dev-m1sk9-s2

k3s の server ノード (control-plane) です．ArgoCD・Sealed Secrets と，Prometheus / Loki / Grafana などの observability スタック (`m1sk9.dev/pool=observability`) を担当します．

計測日: 2026-10-18 (実機で `hostnamectl` / `lscpu` / `free` / `lsblk` を実行して取得)

## ハードウェア

| 項目 | 内容 |
|---|---|
| 機種 | Microsoft Surface Laptop 5 (ノート PC) |
| CPU | Intel Core i5-1235U (10 コア / 12 スレッド，最大 4.4 GHz) |
| メモリ | 16 GB (使用可能 15 GiB) |
| ストレージ | KIOXIA KBG50ZNS512G (NVMe SSD，512 GB) |
| GPU | Intel Iris Xe Graphics (内蔵) |
| 有線 NIC | USB Ethernet アダプタ (`enx*`) |
| 無線 NIC | `wlp0s20f3` (未使用) |

## ソフトウェア

| 項目 | 内容 |
|---|---|
| OS | Debian GNU/Linux 13 (trixie) |
| カーネル | 6.19.8 (surface カーネル) |
| k3s | v1.36.5+k3s1 (server，datastore は SQLite) |
| ホスト名 (MagicDNS) | `dev-m1sk9-s2` |
| Ansible inventory | `s2` (`k3s_servers`) |
| node label | `m1sk9.dev/pool=observability` |
| Tailscale タグ | `tag:k3s`，`tag:k3s-server`，`tag:observability`，`tag:exit-node` |

## ディスク構成

| パーティション | サイズ | 種別 | マウント先 |
|---|---|---|---|
| `nvme0n1p1` | 976 MB | vfat | `/boot/efi` |
| `nvme0n1p2` | 460.2 GB | ext4 | `/` |
| `nvme0n1p3` | 15.8 GB | swap | - |

## 運用上の注意

- 有線接続は USB Ethernet アダプタ経由です．アダプタの抜けや相性で NIC 名が変わると接続が切れるため，注意してください．
- k3s の `node-ip` は Tailscale IP と一致させる必要があります．Tailscale IP が変わったら `tailscale ip -4` と `/etc/rancher/k3s/config.yaml` の `node-ip` を突き合わせてください．LAN の IP アドレスと Tailscale IP は変わりうるため，この文書には記載していません．
- `server:` は agent 側の設定です．server の `config.yaml` に書くと自分自身へ join しようとして再起動ループになります．
- k3s の datastore (SQLite) と Sealed Secrets の鍵はホストにしか存在しないため，restic でバックアップしています ([ansible/README.md](../../ansible/README.md) 参照)．
