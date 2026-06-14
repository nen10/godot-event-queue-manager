# EQM-031 UX

利用者 = addon consumer (L1 policy 選択、CTB)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. speed/cost で次ターン時刻を自動算出 | high | low | low | adopt | CTB の核。consumer は speed と cost を渡すだけ。 |
| B. haste/slow = data[speed] 変更 | high | low | low | adopt | 状態変化は acceptance 側。policy が毎回読む。 |
| C. delay は int (ceil 除算) | high | low | low | adopt | float を ordering に入れない (§12)。 |

## User goal

EQCTBPolicy を選び actor に speed を与えると、速い actor ほど多く行動し、重い行動ほど次ターンが遅れ、wait は次ターンが早まり、haste/slow (speed 変更) が次ターン時刻に反映される。

## Operation steps

1. `var pol := EQCTBPolicy.new()` (speed_key=&"speed", base_cost, scale 既定)。
2. actor register、`state.data["speed"]` 設定。
3. `pol.seed(rt, actor_ids)` → 初期 charge で first turn を投入。
4. loop: advance → `pol.on_turn_finished(rt, actor, EQActionResult.new(cost, 0))` で次ターンを cost/speed から算出。
5. haste/slow: `state.data["speed"]` を変更すると次回 reschedule に反映。

## 既存 UX との干渉

新規 L1 policy。EQPolicy 契約を実装。API surface 変更 → golden 更新。
