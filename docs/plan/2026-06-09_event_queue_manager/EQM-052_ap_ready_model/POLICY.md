# EQM-052 POLICY

## 採用判断

- **EQActionResolutionPolicy (L2)** は EQPolicy 契約 (seed/on_turn_finished) を実装する Action Resolution Turn-Based policy。layer は L2 (AP/reservation の深層パス; base EQPolicy は L1)。
- **AP model (整数決定的)**:
  - AP は `data[ap_key]` (既定 &"ap")。recovery は per-actor `data[recovery_key]` (既定 recovery_per_tick)。
  - ready turn は AP が `ap_max` に回復した時点。**ready delay = ceil(spent_AP / recovery)** = 「解決時間 = AP が N 回復するまで」。
  - seed: AP=0 から first ready = `ceil(ap_max / recovery)`。
  - on_turn_finished (= wait close): `spent = result.cost (>0) else action_ap_cost`; `ap_after = ap_max - spent` を data へ; 次 ready を `current_tick + ceil(spent / recovery)` に schedule。
- **turn closes through wait**: on_turn_finished が turn の close。cost が次 ready の timing を決める (wait=小 cost→早い、heavy→遅い)。
- **ready reservation を具体化**: `ready_reservation_for(runtime, actor_id, spent)` が EQReservation(kind=READY, delay=AP回復delay) を返す (EQM-050 READY kind)。
- full event-line backend / solve condition への還元は EQM-053 (reducibility) / EQM-060。本 task は AP delay 駆動。

## 不採用判断

- AP を built-in field 化 (data 経由)。
- event-line backend の本 task 実装 (EQM-053 で reduction 証明、backend は後続)。
- float を delay に使う (§12)。

## Invariants

- ready delay は int >= 1。recovery<=0 は 1 にクランプ。
- AP spend/recovery は決定的 (同 cost+recovery → 同 delay、同 data[ap])。
- ready turn は AP が ap_max に回復した点 (spent を回復しきる)。
- core ordering を変えない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| ready delay | ceil(spent/recovery)、int>=1 | 非決定 / float | seed=ceil(ap_max/rec)、turn 後=ceil(cost/rec) |
| data[ap] | ap_max - spent (決定的) | AP 喪失 | turn 後 data[ap] assert |
| wait close | 次 ready が schedule される | turn が閉じない | on_turn_finished 後 ready turn pending |
| ready_reservation_for | kind=READY, delay=回復delay | 予約形不一致 | reservation の kind/delay assert |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| cost<=0 | action_ap_cost | normal action 既定 | — | normal delay |
| recovery<=0 | 1 にクランプ | div0/停滞回避 | — | (defensive) |
| 離脱 actor | 再投入しない | 幽霊 turn 防止 | — | (共通機構) |
