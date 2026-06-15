# EQM-052 UX

利用者 = Action Resolution Turn-Based を作る game developer (L2 deep path)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. AP 回復で次 turn (ready) が来る | high | low | low | adopt | 行動解決ターン制の核。 |
| B. 行動 cost が AP を消費し次 delay を決める | high | low | low | adopt | 重い行動ほど次が遅い。 |
| C. wait で turn を閉じ次 ready を schedule | high | low | low | adopt | turn の明示クローズ。 |
| D. ready_reservation_for で READY 予約を取得 | medium | low | low | adopt | reservation object として扱える。 |
| E. AP を built-in field 化 | low | med | low | reject | data[ap_key] (acceptance 定義)。 |

## User goal

EQActionResolutionPolicy を選び actor に AP recovery を与えると、AP が回復しきった時点で ready turn が grant され、行動が AP を消費し、wait で turn を閉じると次の ready が AP 回復 delay 後に schedule される。すべて整数で決定的。

## Operation steps

1. `var pol := EQActionResolutionPolicy.new()` (ap_max/recovery_per_tick 既定; per-actor recovery は data[ap_recovery])。
2. actor register、`data["ap_recovery"]` 設定 (任意)。
3. `pol.seed(rt, actor_ids)` → AP 回復後の first ready。
4. loop: advance (ready turn) → `pol.on_turn_finished(rt, actor, EQActionResult.new(ap_cost, 0))` (= wait close)。
5. (任意) `pol.ready_reservation_for(rt, actor, cost)` で READY 予約 object。

## 既存 UX との干渉

新規 L2 policy。EQPolicy 契約を実装、EQM-050 の READY 予約を利用。L0/L1 不変。golden 更新。
