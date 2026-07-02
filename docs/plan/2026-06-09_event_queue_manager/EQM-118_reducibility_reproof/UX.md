# EQM-118 UX — reducibility 再証明

user goal: 「CTB/Energy/Wait-Turn は product の conditions + event-line で本当に組める」ことが、専用 policy と同一の解決列 (trace) として証明されている — model の一般性を信頼して深層 (L2/L3) に踏み込める。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. product pipeline 構成 vs dedicated の trace 部分列一致 | high | medium | medium | adopt | EQM-053 の縮小 (手書き sim) を解消し、実装された model 自体を証明する |
| B. EQM-053 の手書き sim を temporal に強化 | low | low | low | reject | 「product model 経由」という契約 (SEM §16.1) を満たさない |
| C. byte 同一 trace 比較 | — | — | — | reject | kind/補助 record の構造差により不可能。resolved 射影が最強の共通部分 |

## Operation steps (開発者にとっての意味)

1. WT/CT 系の game は dedicated policy でも、conditions + event-line の宣言でも書ける — どちらも同じ解決列になることが test で保証される。
2. dedicated に無い規則 (条件つき行動・失効・反応) が必要になった時点で、同じ進行のまま L2 へ乗り換えられる。

- 採用 UX: 両輪の証明 (dedicated ↔ 抽象 sim は旧 test、dedicated ↔ product は本 test)。
- 干渉: なし (product 変更は submit 時点評価のみ、既存 test 無変更 green が条件)。
