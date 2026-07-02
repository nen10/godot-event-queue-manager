# EQM-114 POLICY — window object model

## 採用判断

- **暗黙 root window (nest 0)**: L0 の turn_ready→suspend を「常時 open の base-operator window」として統一 (Q36 user 確定)。root は trace しない (L0 golden 不変)。明示 window は open/close とも trace する。
- **deadline は定義点検査** (SUB_TASKS E 不採用理由参照): 検査点 = resolve_next の pop 後 + step_tick。`current_tick >= deadline` で発火。外側 window の deadline は内側 window ごと rollback close する (cause: deadline)。
- **budget**: open 時に owner state `data[budget_key]` から `cost` を控除。close で返さない (Q02 非回復)。不足は WINDOW_BUDGET_INSUFFICIENT で open 拒否。`max_window_depth` (既定 16) は絶対 backstop。cost の単調関数は acceptance 側計算 (EQM は控除と拒否のみ)。
- **commit guard**: EQTransaction の commit は snapshot 置換であり、draft 中に live が変わった場合の commit は pop 済み event を復活させる。よって close_window(commit=true) は `is_live_unchanged()` を要求し、違反は WINDOW_COMMIT_CONFLICT (CONTRACT_VIOLATION) + rollback。frozen window (既定) は suspend 中 live 不変なので影響なし。
- **close は top-only**: 非 top の close 指定は WINDOW_CLOSE_INVALID。root は close 不能。

## 不採用判断

- deadline の scheduler event 化 / EQManager suspend への trace / budget の自動 refund (Q02 違反)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| window stack | root 常在・明示 window は LIFO | 順序破壊 | top-only close test |
| budget | open で控除・close で非回復 | silent refund | 連続 open/close の残高 test |
| deadline | 既定 rollback+close、hook で明示 commit のみ | silent default 行動 | deadline test (live 不変) + hook commit test |
| commit | live 不変時のみ | pop 済み event の復活 | commit conflict test |
| trace | 明示 window のみ window_opened/closed | L0 golden 汚染 | demo golden 不変 (test.sh) |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| EQTransaction 単体 API | 不変のまま併存 (window が所有するだけ) | EQM-070/071 互換 | v2 で window 経由へ一本化検討 | 既存 transaction tests |
| commit-at-deadline with live drift | fault + rollback (安全側) | clobber 防止 | draft-log replay commit を将来実装したら緩和 | conflict test |

## ERROR_CONTRACT 追加

`eqm.window.depth_limit` / `eqm.window.budget_insufficient` (BUDGET_EXCEEDED)・`eqm.window.close_invalid` / `eqm.window.commit_conflict` (CONTRACT_VIOLATION)。
