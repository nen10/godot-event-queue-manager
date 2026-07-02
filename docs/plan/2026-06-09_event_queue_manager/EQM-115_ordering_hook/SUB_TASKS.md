# EQM-115 SUB_TASKS — ordering hook

## Complexity

Class: C2
Reason: 単一拡張点 (順序 hook) の追加。適用点は pipeline の 2 箇所 (同時成立 conditional / 同時 fired reactions) に閉じ、master comparator (§3) は不変。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. `set_order_hook(Callable)` (EQReservationRuntime) | SEM §7.1 | 採用 | `order_simultaneous(candidates: Array[Dictionary]) -> Array[int]` (permutation)。未設定 = 発行順 (既定) |
| B. candidates view の構築を EQM 側で行う | Q20 制約 | 採用 | serializable のみ (actor stat / tags / priority / event-line 値 / nest level / 発行 index)。live object は構築上混入不能 + test で検証 |
| C. 不正 permutation の安定 fault + 発行順 fallback | 決定性 | 採用 | 長さ/重複/範囲を検証。silent 採用はしない (fault 記録) |
| D. hook 出力の trace (`order_hook_applied`) + replay byte 同一性 | Q20 golden 被覆 | 採用 | 同一入力 2 run の jsonl 一致で golden 相当を保証 |
| E. EQConfig への hook 保持 | — | 不採用 | Callable は Resource に serialize 不能。named registry 群と同じ「起動時登録」で統一 (queue target files からの deviation として記録) |
| F. composite atomic bundle | — | 不採用 (defer) | SEM §7.1 staging どおり v1.x 後段。本 task は順序決定のみ |

Scheduled task: なし。
