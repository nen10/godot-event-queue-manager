# EQM-114 UX — window object model

user goal: game 開発者が「行動 window」(操作 nest・制限時間つき手番・rollback 可能な draft) を 1 つの object で扱え、開閉と時間切れが trace で説明される。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. EQWindow + stack (暗黙 root 統一) | high | low | medium | adopt | Q36 確定。save cap (Q01) の基準が自然に定まる |
| B. EQTransaction を直接使い続けるだけ | medium | medium | low | reject (併存は維持) | nest/deadline/budget の契約が宙に浮く |
| C. deadline の silent default 行動 | low | high | low | reject | 禁止原則。既定 rollback + hook 明示 commit (Q37 確定) |

## Operation steps

1. `w := rr.open_window(&"hero", &"command", deadline, cost, &"meta_budget")` — nest と budget は EQM が enforce。
2. `w.draft.draft_push(...)` で仮行動 → `rr.close_window(true)` で commit / `rr.close_window()` で破棄。
3. 制限時間つき手番は `deadline` (絶対 tick)。時間切れは既定で draft rollback + `window_closed(cause: deadline)`。commit したい game は `w.pre_close` hook で明示 commit。
4. trace の `window_opened/closed` で開閉・原因が読める (暗黙 root は trace されない)。

- 採用 UX: first-class window。廃止/保留: なし (EQTransaction 単体 API は互換併存)。
- 干渉: EQM-070/071 の transaction tests は不変で green を維持する。
