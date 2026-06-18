# EQM-084 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — public API 全体の dogfood、ergonomics 判断)
Reason:
- public API のみで playable Action Resolution slice を組み、reservation/trigger/transaction/presentation/AP/RNG を実 consumer flow に結線。golden trace + friction report。
- Phase 8 records (EffectRecord/PresentationBuffer) を実際に consumer が生成する経路を初めて通す (review 境界観察の検証)。

Required artifacts: Complexity header / Task Resolution / IMPLEMENTATION_PLAN。friction 判断は DOGFOOD_FRICTION report。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| dogfood/action_resolution/battle.gd | public API のみの AR slice | adopt | EQManager+EQActionResolutionPolicy / EQReservationRuntime / EQTriggerEngine+EQCondition / EQEffectChunk+EQPresentationBuffer / EQRng。 |
| golden trace | dogfood の決定性証明 | adopt | tests/golden/dogfood_action_resolution.trace.jsonl。 |
| DOGFOOD_FRICTION report | API ergonomics findings | adopt | docs/review/DOGFOOD_FRICTION_2026-06-18.md。各 finding を candidate / no-change 記録。 |
| test_project/dogfood symlink | test から res:// 到達 | adopt | demos symlink と同様。 |
| runtime internal への直接アクセス | — | reject | public class のみ preload。 |

## Scheduled Task Audit

新規 scheduled task は friction report の判断に依存 (大半 no-change / EQM-100 manual へ畳む見込み)。次の依存解放は EQM-085 で既に満たし済み (084 は 085 の依存ではない)。
