# EQM-070 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — transaction model は基盤、EQM-071 が乗る)
Reason:
- player-turn draft transaction (apply/inspect/rollback/commit)。PROJECT_PROFILE「transactional player turns: wait 前 rollback を first-class」。
- EQM-012 snapshot/restore + EQM-033 EQSnapshot.equals の上に構築。EQM-071 (wait-commit) が依存。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY (model + Invariant) / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQTransaction (working-copy model) | draft を working copy に適用、commit で live へ昇格 | adopt | begin=live snapshot + working clone。draft ops は working のみ。rollback=working を base へ。commit=live を working へ。 |
| live unchanged before commit | drafting 中 live は不変 | adopt | `is_live_unchanged()` = EQSnapshot.equals(live.snapshot(), base)。 |
| draft inspection | 適用した draft を観察 | adopt | working() / draft() (記録)。 |
| snapshot-on-live (live を直接変更 + restore で rollback) | — | reject | drafting 中 live が変わり「unchanged before commit」を満たさない。working-copy が明快。 |
| transaction が runtime/policy を駆動 | — | defer→EQM-071 | 本 task は scheduler 上の draft/commit/rollback。wait-commit + ready 予約は EQM-071。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-071 (wait/end-turn commit boundary)。deterministic replay は EQM-072。
