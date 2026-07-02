# EQM-112 SUB_TASKS — event-line backend

## Complexity

Class: C3
Reason:

- 新規 L3 class + 性能予算 test + API surface (初の L3 tag) にまたがる。
- pipeline 統合 (EQM-113) と snapshot v2 (EQM-117) は後続 task の scope で、本 task は backend data structure と primitives に閉じる。

Required artifacts: C2 + dependency/test matrix + state/invariant table。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. EQEventLines (L3) | SEM §4.6 の data model | 採用 | {id, value, rate} table + issue/advance/re_rate/poll + counter 採番 + faults 記録 |
| B. watched 導出 + sparse polling | SEM §4.3 | 採用 | bound terms から line_id 集合を導出し、watched かつ rate≠0 のみ poll |
| C. sweep rule registry | SEM §4.7 | 採用 | named registry (登録順固定)、actor_id 昇順走査、rule name trace |
| D. `event_line_progressed` 実 emit | SEM §11 | 採用 | EQTrace へ cause 別 (issued/advanced/poll/re_rated/sweep_rule) に記録 |
| E. Q43 予算 test | SEM §12.1 | 採用 | 300 watched lines poll + 200 actors sweep の粗い regression guard |
| F. primary line の scheduler 同期 | — | 部分採用 | `sync_primary(tick)` primitive のみ提供。呼び出し統合は EQM-113 |
| G. crossing-tick 最適化 backend (Q17 (b)) | — | 不採用 | v1.x は per-tick polling 既定。golden 等価な最適化は将来 task |

Scheduled task: なし (F の統合 / snapshot 組込みは既存 EQM-113/117 が owner)。
