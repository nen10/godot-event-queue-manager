# EQM-053 SUB_TASKS

## Complexity

Class: C2 (delegated)
Reason:
- tests-only。固定ターゲット (dedicated policy の resolved order) に一致させる metamorphic equivalence 証明。設計自由度がほぼ無い (忠実再現)。
- **委譲**: 設計縮小リスクが低く明確なため、保守的 Codex 5.5 (gpt-5.5 xhigh) executor へ P2 委譲 (user-authorized 2026-06-15)。orchestrator が contract + gate を所有。

Required artifacts: Complexity header / Task Resolution / Contract (IMPLEMENTATION_PLAN) / 委譲記録。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| reducibility test (per-tick event-line sim) | CTB/energy/wait を per-tick 進行で再現し dedicated policy と order 一致 | adopt | test 内に per-tick simulator を書き、dedicated policy の trace と比較。 |
| speed/cost/tie-break matrix | 一致を行列で確認 | adopt | 複数 speed/cost/同値 tie で A==B。 |
| per-tick polling ≡ closed-form | Q17: naive ≡ optimized | adopt | dedicated policy(閉形式 delay) と per-tick sim が同 order。 |
| divergence は model gap として記録 | reducibility は強制でない (§1.1) | adopt | 不一致が出たら test で surface + 記録 (現状は一致見込み)。 |
| 新規 product code | — | reject | tests-only。runtime/resource を変更しない。 |

## 委譲 (P2)

- executor: Codex 5.5 (gpt-5.5 xhigh), 保守的実行 (tight contract で behavior 制約)。
- isolation: 現 tree で実行し、orchestrator が diff review + `./tools/test.sh` gate を commit 前に行う。scope 逸脱は revert。
- repair 上限 3。超過で orchestrator が P0 で引き取る。
- contract は `IMPLEMENTATION_PLAN.md` (acceptance / scope / gate)。

## Scheduled Task Audit

新規 scheduled task なし。EQM-053 完了で Phase 5 milestone。
