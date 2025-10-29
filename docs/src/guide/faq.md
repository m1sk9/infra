---
layout: doc
---

# FAQ

### Q. Tailscale Lock を使用したい

メンバー権限の場合は Tailscale Lock は使用できません．

管理者権限を持つメンバーに連絡して，Tailscale Lock の設定を行ってもらってください．

### Q. DERP サーバとは?

DERP (Detour Encrypted Routing Protocol) サーバは，Tailscale ネットワーク内のデバイス間で安全に通信を中継するためのサーバです．

Tailnet デバイス間の接続の大半は，別の Tailnet デバイスへの直接接続するためのみ DEAP サーバーを使用します．

ただし，NAT やファイアウォールの制約により直接接続が確立できない場合，DERP サーバが中継役として機能します．

詳しくは Tailscale Docs を参照してください．

[DERP servers - Tailscale Docs](https://tailscale.com/kb/1232/derp-servers)
