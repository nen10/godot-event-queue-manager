# EQM-115 UX — ordering hook

user goal: 「複数 entity の同時到達はベース WT が低い方から」のような上位順序規則を、決定性を壊さず 1 つの拡張点で宣言できる。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. 順序 hook (permutation 返し) 1 点 | high | low | low | adopt | Q20/Q38 確定。「完走保証つき拡張点」 |
| B. 自由 comparator で master ordering を差し替え | medium | high | medium | reject | §3 の全順序決定性を壊す (禁止) |
| C. composite atomic bundle も同時に | medium | medium | high | reject (defer) | §7.1 staging。順序のみ先行 |

## Operation steps

1. 起動時に `rr.set_order_hook(func(candidates): ...)` を 1 回登録する。
2. hook は serializable な candidates (stats/tags/lines/nest/発行 index) を読み、並び (index の permutation) を返す。
3. 未登録なら発行順。返しが不正なら fault + 発行順 fallback (silent 採用なし)。適用は trace の `order_hook_applied` で確認できる。

- 採用 UX: 単一 hook。廃止/保留: なし。干渉: なし (hook 未設定時は v1.0 挙動と同一)。
