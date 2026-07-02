# EQM-115 POLICY — ordering hook

## 採用判断

- **適用点は 2 箇所のみ**: (1) 同一評価点で solve 成立した pending conditional 群の push 順、(2) 同一 sweep で fired した reaction 群の schedule 順。どちらも「新規 sequence の割当順」を並べ替えるだけで、master comparator (§3) と既存 entry の key は不変。
- **view は EQM が構築** (acceptance code に live object を渡さない): {index (発行順), actor, stats (actor state data の deep copy), tags, priority, nest_level, lines (event-line 値)}。float は stats 経由で hook 入力に現れてよい (§7 の scoped exception) が、出力は permutation (int) のみ。
- **不正 permutation = 安定 fault + 発行順 fallback**: 黙って発行順に落とさない (fault 記録; dev halt)。
- **trace**: hook 適用ごとに `order_hook_applied` {count, order}。golden 被覆は同一入力 2 run の byte 同一性 test で保証 (専用 golden fixture は EQM-118 の product 経路 golden に含める)。
- **既定 (hook なし) = 発行順** — v1.0 挙動と同一 (退行なし)。

## 不採用判断

- EQConfig 保持 (SUB_TASKS E) / composite bundle (F, defer 維持) / 適用点の一般化 (任意の同 tick event 群への適用 — scheduled 済み event の順序は §3 comparator の領分)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| master comparator | hook は sequence 割当順のみ変える | §3 の侵食 | 既存 ordering tests 不変 |
| view | serializable のみ (contains_live_object false) | live object leak | view 検証 test |
| permutation | 全単射・範囲内 | 欠落/重複 | 不正 permutation test |
| 決定性 | 同一入力 → byte 同一 trace | hook 内非決定 | 2-run 同一性 test (非決定 hook は acceptance の責務違反として docs 明記) |

## ERROR_CONTRACT 追加

`eqm.order.hook_invalid` (CONTRACT_VIOLATION) — 不正 permutation。
