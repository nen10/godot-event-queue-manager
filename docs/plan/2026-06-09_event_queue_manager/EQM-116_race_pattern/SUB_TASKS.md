# EQM-116 SUB_TASKS — race pattern

## Complexity

Class: C3
Reason: pipeline への race 管理追加 + trace 語彙 + overlay の表示集約。既存契約 (§5.4 invalidation-wins / §7.1 hook) の合成で、勝敗の新規順序規則は導入しない。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. `submit_race(members) -> race_group_id` | SEM §5.2 | 採用 | 同一 effect・異なる solve_conditions の複数予約を一括発行。gid は deterministic 採番 (`eqm.race.<seq>`) |
| B. 勝者確定 = 最初に解決した member | §5.4 (Q28) | 採用 | 同時成立の順序は既存 §7.1 hook → 発行順に委ね、race 専用規則を作らない |
| C. 敗者一掃 (`closed_by: race_lost`) | §5.2 | 採用 | pending conditional は除去、scheduled は cancel。invalidation 記録に race_group field |
| D. trace 語彙 `race_opened` / `race_resolved` | §11 | 採用 | EQM 内部 debug 表示 (全候補が trace に可視) |
| E. overlay の候補群集約 | 3 表示分離の最小実装 | 採用 | EQDebugOverlay: explanation の race_group が連続する行を 1 つの候補群 row に集約 (game-dev debug)。in-game presentation (勝者のみ) は Phase 8 経路が既に勝者しか受け取らない |
| F. race 専用の勝者 comparator | — | 不採用 | Q28 確定 (hook → 発行順)。専用規則は UX_PATH_REDUCTION に反する |

Scheduled task: なし。
