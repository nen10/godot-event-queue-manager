# EQM-062 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — 決定性/安全に直結する cycle guard)
Reason:
- rumination (反芻 = 再武装/再スケジュール) と **無限連鎖を止める cycle guard** を実装。SEMANTICS §8 (trigger nest = bounded round + cycle guard)。
- eq_reservation_runtime + eq_trigger_engine の両方に触れる。RUNTIME_RESILIENCE の BUDGET_EXCEEDED に対応する明示 error。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY (rumination + guard + Invariant) / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQTriggerEngine rumination 再武装 | 発火後 rumination>0 なら decrement+再武装 | adopt | rumination N = N+1 回発火 (0=one-shot, EQM-061 互換)。 |
| EQReservationRuntime rumination 再 schedule | 解決後 rumination>0 なら decrement+再 submit | adopt | "rumination count decrements and reschedules"。 |
| cycle guard (max_chain) | 無限連鎖を bounded round で止め明示 error | adopt | `fire_cascade(view, tick, follow_up)`、steps>=max_chain で `TRIGGER_CHAIN_LIMIT` (BUDGET_EXCEEDED) を faults に記録し停止。 |
| 新 error code | chain limit の安定 code | adopt | `eqm.trigger.chain_limit` append-only。 |
| crash で停止 | — | reject | shipped fail-safe: 明示 error event + 停止、crash しない (RUNTIME_RESILIENCE)。 |
| window nest budget との統合 | — | defer | §8: window+trigger nest 交差は EQM-061/062 narrow 項目。本 task は trigger 連鎖の bounded round + absolute max (engineering backstop)。 |

## Scheduled Task Audit

新規 scheduled task なし。EQM-062 完了で Phase 6 (Trigger/reaction engine) milestone。
