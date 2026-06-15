# EQM-040 UX

利用者 = addon consumer (L1 policy 選択、roguelike energy)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. energy threshold で行動、cost を spend | high | low | low | adopt | roguelike の核。 |
| B. carry-over (remainder 持ち越し) | high | low | low | adopt | cheap action で次が早い。CTB との差別化。 |
| C. speed で充填速度 | high | low | low | adopt | faster がより頻繁に行動。 |
| D. delay は int (ceil 除算) | high | low | low | adopt | float を ordering に入れない。 |

## User goal

EQEnergyPolicy を選び actor に speed を与えると、energy が threshold に達した actor が行動し、行動 cost が次までの時間を決め、余った energy は carry-over されて次の行動を早める。速い actor ほど多く行動する。

## Operation steps

1. `var pol := EQEnergyPolicy.new()` (speed_key=&"speed", threshold, base_cost 既定)。
2. actor register、`data["speed"]` 設定。
3. `pol.seed(rt, actor_ids)` → energy 0 から threshold までの初期 delay。
4. loop: advance → `pol.on_turn_finished(rt, actor, EQActionResult.new(cost,0))`。cheap cost は carry-over で次を早める。

## 既存 UX との干渉

新規 L1 policy。EQPolicy 契約を実装。API surface 変更 → golden 更新。
