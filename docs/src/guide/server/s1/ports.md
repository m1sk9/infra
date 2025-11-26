---
layout: doc
---

# dev-m1sk9-s1: 使用ポート番号

- `dev-m1sk9-s1` で使用しているコンテナのポート番号の一覧です．
- サービスデプロイ時はこれらのポート番号に衝突しないように注意してください．

| サービス名 | コンテナ名 | ポート番号 |
| ---------- | ---------- | ---------- |
| babyrite | `babyrite-app-1` | 未使用 |
| Grafana Promtail | `promtail` | 未使用 |
| Grafana Loki | `loki` | `3100/tcp` |
| Prometheus | `prometheus` | `9090/tcp` |
| Node Exporter | `node-exporter` | 未使用 |
| withoutbg | `withoutbg-app-1` | `8080/tcp` |
