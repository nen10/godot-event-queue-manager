# EQM-041 UX

利用者 = addon consumer (L1 policy 選択、Tactics Ogre / FFT wait-turn)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. wait 値で次 ready unit へ即解決 | high | low | low | adopt | TO/FFT の核。idle tick なし。 |
| B. action cost が次 wait を決める | high | low | low | adopt | 重い行動ほど次が遅い。 |
| C. equal wait は agility→登録順 | high | low | low | adopt | 「ベース WT 低い方先」(Q09) を agility で表現、明示。 |
| D. learning-path demo + golden | high | low | low | adopt | TO 風 sample を trace で証明。 |

## User goal

EQWaitTurnPolicy を選び unit に wait と agility を与えると、最小 wait の unit に即座に手番が回り、行動 cost が次の wait を決め、同 wait は agility 高い順 (同値は登録順) で解決される。

## Operation steps

1. `var pol := EQWaitTurnPolicy.new()` (wait_key=&"wait", agility_key=&"agility", base_cost 既定)。
2. unit register、`data["wait"]` / `data["agility"]` 設定。
3. `pol.seed(rt, actor_ids)` → due_tick=wait で投入。
4. loop: advance (clock が次 ready へ jump) → `pol.on_turn_finished(rt, unit, EQActionResult.new(cost,0))`。

## tie-break 説明 (acceptance)

equal wait (= 同 due_tick) のとき: priority=agility の降順で先後を決め (速い unit が先)、agility も同値なら登録順 (sequence) で確定する。決定的全順序。

## 既存 UX との干渉

新規 L1 policy + demo。EQPolicy 契約を実装。API surface 変更 → golden 更新。demo golden 追加。
