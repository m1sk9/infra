# dev-m1sk9-s1

k3s の agent ノードです．Discord bot などのアプリケーションワークロード (`m1sk9.dev/pool=apps`) を担当します．

計測日: 2026-10-18 (実機で `hostnamectl` / `lscpu` / `free` / `lsblk` を実行して取得)

## ハードウェア

| 項目 | 内容 |
|---|---|
| 機種 | NEC PC-NS150GAR (ノート PC) |
| CPU | Intel Celeron 3855U (2 コア / 2 スレッド，1.6 GHz) |
| メモリ | 4 GB (使用可能 3.7 GiB) |
| ストレージ | WDC WD10JPVX (HDD，1 TB) |
| GPU | Intel HD Graphics 510 (内蔵) |
| 光学ドライブ | HL-DT-ST DVDRAM GUD0N (未使用) |
| 有線 NIC | `enp1s0` |
| 無線 NIC | `wlp2s0` (未使用) |

## ソフトウェア

| 項目 | 内容 |
|---|---|
| OS | Debian GNU/Linux 13 (trixie) |
| カーネル | 6.12.113 (Debian 標準) |
| k3s | v1.36.5+k3s1 (agent) |
| ホスト名 (MagicDNS) | `dev-m1sk9-s1` |
| Ansible inventory | `s1` (`k3s_agents`) |
| node label | `m1sk9.dev/pool=apps` |
| Tailscale タグ | `tag:k3s`，`tag:k3s-agent` |

## ディスク構成

| パーティション | サイズ | 種別 | マウント先 |
|---|---|---|---|
| `sda1` | 976 MB | vfat | `/boot/efi` |
| `sda2` | 926.6 GB | ext4 | `/` |
| `sda3` | 3.9 GB | swap | - |

## 運用上の注意

- HDD のため I/O 性能が低いです．PVC は k3s `local-path` でこのノードのディスクに固定されるので，I/O の重い workload は載せないでください．
- メモリが 4 GB と小さいため，新しい workload を載せる際は `resources.requests` / `limits` を必ず設定してください ([DEPLOYMENT.md](../DEPLOYMENT.md) 参照)．
- 通信は有線 NIC で行い，無線 NIC は使っていません．LAN の IP アドレスと Tailscale IP は変わりうるため，この文書には記載していません．参照は MagicDNS 名 (`dev-m1sk9-s1`) で行ってください．
- 2026-10-13 に Arch Linux から Debian 13 へ再インストールしました (Issue #475)．
