# EQM-061 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — trigger 発火意味論は design core)
Reason:
- reaction の **発火/失効意味論** (sweep point での condition 照合・duration 失効・owner/source 区別) を確立する。EQM-062 (rumination + cycle guard) が乗る。
- L2 trigger engine。設計縮小リスクが高く P0。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY (発火意味論 + Invariant) / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQTriggerEngine (L2) | armed reaction を sweep point で照合・発火 | adopt | arm(reservation, condition, tick) / on_event_resolved(view, tick)→fired / armed_count。 |
| sweep point 発火 | 解決後 collection window (SEMANTICS §6) | adopt | on_event_resolved を解決直後に呼ぶ。interleave しない。 |
| duration 失効 | 武装時刻+duration 経過で発火前に drop | adopt | armed_at + duration (-1=∞)。expire を fire の前に評価。 |
| owner/source 区別 | counter は敵 source/owner target で発火 | adopt | EQCondition で match_target=owner / custom predicate で source 区別。 |
| 発火 = one-shot (EQM-061) | 反応は1回で消費 | adopt | rumination (再武装 N 回) は EQM-062。 |
| condition は arm 時に渡す | EQActionDefinition を変えない | adopt | reservation と condition を engine が pair。 |
| rumination 再武装 / cycle guard | — | defer→EQM-062 | 本 task は one-shot 発火 + duration 失効。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-062 (rumination + cycle guard)。fired reaction の実 scheduling 連携 (runtime) は EQM-062 / dogfood で。
