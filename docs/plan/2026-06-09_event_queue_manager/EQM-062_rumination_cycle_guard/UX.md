# EQM-062 UX

利用者 = Action Resolution game developer (L2 reaction/rumination)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. rumination で反応/予約が N 回繰り返す | high | low | low | adopt | 反芻 (counter を数回など)。 |
| B. cycle guard が無限連鎖を止める | high | low | low | adopt | 暴走を防ぎ明示 error。 |
| C. 停止は crash でなく error event | high | low | low | adopt | shipped fail-safe (RUNTIME_RESILIENCE)。 |

## User goal

rumination 付き reservation/reaction は count 分だけ再スケジュール/再武装され、count が尽きると止まる。trigger 連鎖が暴走しても max_chain で打ち切られ、`TRIGGER_CHAIN_LIMIT` の明示 error が記録される (crash しない)。

## Operation steps

1. reservation/reaction の `rumination` を設定 (EQActionDefinition)。
2. resolve/fire のたびに rumination が decrement、>0 なら再武装/再 schedule。
3. 暴走しうる連鎖は `EQTriggerEngine.fire_cascade(view, tick, follow_up)` で bounded。超過時 `faults` に chain_limit。

## 既存 UX との干渉

eq_trigger_engine に rumination 再武装 + fire_cascade、eq_reservation_runtime に rumination 再 schedule を追加。EQTriggerEngine surface 変更 → golden 更新。+1 error code。
