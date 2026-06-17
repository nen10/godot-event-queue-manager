# EQM-061 UX

利用者 = Action Resolution game developer (L2 reaction)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. armed reaction が条件一致で発火 | high | low | low | adopt | counterattack 等の核。 |
| B. duration 経過で発火前に失効 | high | low | low | adopt | 反応窓が閉じたら撃たない。 |
| C. owner/source 区別 | high | low | low | adopt | 敵攻撃にのみ反応、自傷に反応しない。 |
| D. sweep point 発火 (解決後) | high | low | low | adopt | 解決中に interleave しない (決定性)。 |

## User goal

reaction preparation (EQReservation REACTION_PREPARATION + EQCondition) を arm すると、一致する incoming event (例: `<損害>`) の解決後に発火し、duration が切れていれば発火せず、owner と event source/target を区別して敵攻撃にのみ反応する。

## Operation steps

1. `var eng := EQTriggerEngine.new()`。
2. `eng.arm(reaction_reservation, condition, current_tick)`。
3. event 解決ごとに `var fired := eng.on_event_resolved(event_view, current_tick)`。
4. fired の各 reservation を consumer/runtime が schedule (counterattack)。

## 既存 UX との干渉

新規 L2 trigger engine。EQCondition (EQM-060)/EQReservation (EQM-050) を利用。L0/L1 不変。API surface 変更 → golden 更新。
