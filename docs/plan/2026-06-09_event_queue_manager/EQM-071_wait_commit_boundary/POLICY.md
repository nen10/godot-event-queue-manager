# EQM-071 POLICY

## 採用判断

- **wait_close (EQActionResolutionPolicy)**: `wait_close(runtime, actor_id, result, transaction = null)` — transaction があれば `transaction.commit()` (draft → live)、その後 `on_turn_finished(runtime, actor_id, result)` で ready 予約 (AP 回復後の次 turn) を schedule。これが「wait commits draft and schedules ready reservation」。
- **immediate actions rollbackable before wait**: player の immediate action は EQTransaction の draft (working copy)。wait 前は `rollback()` で破棄 (live 不変)。EQM-070 の draft/rollback を結線。
- **commit 境界 guard (EQTransaction)**: `_committed` 後は `draft_push`/`draft_cancel` を no-op (-1/false)。commit 後の draft を防ぐ。
- transaction=null の wait_close は commit skip + on_turn_finished のみ (policy 単体・後方互換)。

## 不採用判断

- 部分 undo (個別 action 取消): full rollback で acceptance 充足。将来拡張。
- wait_close が直接 scheduler を操作: commit + on_turn_finished に委ねる (既存契約の合成)。

## Invariants

- wait 前: immediate action は draft のみ、live 不変、rollback 可。
- wait 後: draft が live に反映 + ready 予約が live に存在。
- commit 後 draft 不可 (guard)。
- wait_close は決定的 (同 draft + 同 result で同 live 結果)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| pre-wait draft | live 不変、rollback 可 | 早期 commit | draft 後 is_live_unchanged、rollback で破棄 |
| wait_close | commit + ready schedule | どちらか欠落 | wait 後 live に immediate + ready turn |
| commit guard | commit 後 draft no-op | 二重 commit / 後 draft | committed 後 draft_push == -1 |
| transaction=null | on_turn_finished のみ | null crash | policy 単体 wait_close |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| wait 前 rollback | draft 破棄、live 不変 | 試行錯誤 | — | rollback test |
| commit 後 draft | no-op | 境界整合 | — | committed guard |
| transaction なし | commit skip | policy 単体可 | — | null transaction wait_close |
