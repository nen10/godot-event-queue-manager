# EQM-070 POLICY

## 採用判断

- **EQTransaction (L2, working-copy model)**: `begin` (= _init) で live の snapshot を `_base` に保存し、`_working` を base から復元した clone にする。draft ops (`draft_push`/`draft_cancel`) は **working のみ**に適用。`rollback` は working を base へ復元 + draft 記録 clear。`commit` は live を working の snapshot へ復元 (= draft を live へ昇格)。
- **live unchanged before commit**: drafting は live に触れない。`is_live_unchanged()` = `EQSnapshot.equals(live.snapshot(), _base)`。
- **draft inspection**: `working()` (draft 状態の scheduler) と `draft()` (適用 op の記録) を公開。
- commit 後は `is_committed()` true。再 draft は新 transaction で。
- scheduler レベル (EQM-012 snapshot/restore + EQM-033 equals の上)。runtime/policy 連携 (wait-commit, ready 予約) は EQM-071。

## 不採用判断

- snapshot-on-live (live を直接変更 → rollback で restore): drafting 中 live が変わり acceptance 不適合。
- transaction が runtime/policy を直接駆動 (EQM-071)。
- deterministic RNG (EQM-072)。

## Invariants

- commit 前: live.snapshot() == _base (live 不変)。
- commit 後: live == working (draft 反映)。
- rollback 後: working == _base、draft 記録空。
- draft ops は working の整合 (sequence/generation) を保つ (EQScheduler 経由)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| live (pre-commit) | base から不変 | drafting で live 汚染 | draft 後 is_live_unchanged() true |
| working | draft を反映 | draft 反映漏れ | draft_push 後 working に event |
| rollback | working=base, draft 空 | 部分 rollback | rollback 後 working==base, draft()空, live 不変 |
| commit | live=working | 昇格漏れ | commit 後 live に draft event |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| pre-commit の live 参照 | base と不変 | 確定前は本番不可侵 | — | is_live_unchanged |
| rollback | working を base へ | 試行錯誤の破棄 | — | rollback test |
| commit 済み後の draft | 新 transaction 要 | 二重 commit 防止 | — | is_committed |
