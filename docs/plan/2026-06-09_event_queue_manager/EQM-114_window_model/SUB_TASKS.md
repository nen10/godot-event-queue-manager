# EQM-114 SUB_TASKS — window object model

## Complexity

Class: C3
Reason: 新規 class + pipeline への統合 (deadline 検査点) + budget/深度の enforce。EQTransaction は無変更 (従属のみ)。save 配線 (117)・EQManager 統合は scope 外。

Required artifacts: C2 + dependency/test matrix + state/invariant table。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. EQWindow object | SEM §8.1 | 採用 | {window_id, owner, nest_level, kind, deadline, budget_paid, draft} + to_dict |
| B. window stack を EQReservationRuntime に所有 | §8.1 | 採用 | 暗黙 root (nest 0, L0 await の統一表現) + open/close + trace 実 emit |
| C. budget enforce | §8.1 (Q02) | 採用 | owner state の budget_key から支払い・非回復・絶対 max depth backstop |
| D. deadline = 定義点での tick 検査 | §9 (Q37) | 採用 | resolve_next (pop 後) と step_tick で `current_tick >= deadline` を検査。既定 = rollback + close + cause deadline、pre_close hook で明示 commit |
| E. deadline を scheduler event 化 | — | 不採用 | deadline event の pop 自体が live を変え、EQTransaction の snapshot-commit と衝突 (commit が pop 済み event を復活させる)。Q40 (expiry) と異なり Q37 は event 化を要求していない。検査点 (pop 後/tick 境界) は決定的 |
| F. commit の live 競合 guard | §8.1 運用 | 採用 | commit は `is_live_unchanged()` 必須。違反は WINDOW_COMMIT_CONFLICT + rollback (snapshot-clobber の防止) |
| G. EQManager (L0) の suspend への trace 追加 | — | 不採用 | L0 demo golden を全て変える。暗黙 root window は状態として存在し trace しない (明示 window のみ trace) |

Scheduled task: なし (save 配線は EQM-117、authoring/manual は EQM-119)。
