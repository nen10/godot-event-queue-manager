# EQM-071 SUB_TASKS

## Complexity

Class: C2 (orchestrator-direct — wait 意味論が policy と結合)
Reason:
- EQTransaction (EQM-070) と EQActionResolutionPolicy (EQM-052) を結線。「wait で turn を閉じる = draft commit + ready 予約 schedule」。
- EQTransaction に commit 後 draft 禁止 guard を追加 (commit 境界の正しさ)。EQActionResolutionPolicy に wait_close。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQActionResolutionPolicy.wait_close | wait で commit + ready 予約 | adopt | `wait_close(runtime, actor_id, result, transaction)`: transaction.commit() → on_turn_finished (ready)。 |
| immediate actions rollbackable before wait | wait 前は draft、rollback 可 | adopt | EQTransaction.draft_* + rollback (EQM-070)。本 task で結線。 |
| commit 後 draft 禁止 guard | commit 境界の正しさ | adopt | EQTransaction.draft_push/cancel が _committed なら no-op (-1/false)。 |
| transaction なし wait_close | policy 単体でも動く | adopt | transaction=null なら commit skip、on_turn_finished のみ (後方互換)。 |
| 部分 undo (個別 action) | — | reject(MVP) | full rollback で acceptance 充足。個別 undo は将来。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-072 (deterministic RNG + replay; Codex 委譲候補)。
