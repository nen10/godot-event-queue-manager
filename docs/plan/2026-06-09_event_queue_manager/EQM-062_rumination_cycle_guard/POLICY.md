# EQM-062 POLICY

## 採用判断

- **rumination (EQTriggerEngine)**: 発火時 `remaining_ruminations > 0` なら decrement して **再武装** (ARMED 維持)、else 消費 (除去)。rumination N = N+1 回発火。rumination 0 = one-shot (EQM-061 互換)。
- **rumination (EQReservationRuntime)**: `resolve_next` で解決後 `remaining_ruminations > 0` なら decrement して同 reservation を **再 submit** (reschedule)。count 0 で停止。
- **cycle guard (EQTriggerEngine.fire_cascade)**: trigger 連鎖 (fired reaction が follow-up event を生み更に発火) を bounded round で処理。`steps >= max_chain` (既定 64、engineering backstop) で **打ち切り**、`eqm.trigger.chain_limit` (BUDGET_EXCEEDED) を `faults` に記録。**crash しない** (shipped fail-safe)。
- 新 error code `eqm.trigger.chain_limit` を append-only 追加。

## 不採用判断

- crash / hard assert で連鎖停止 (RUNTIME_RESILIENCE: 明示 error + 継続)。
- window nest budget との統合 cost 設計 (§8 narrow 項目、本 task は trigger 連鎖の bounded round + absolute max)。
- 無制限再武装の黙認 (max_chain で必ず bounded)。

## Invariants

- rumination は決定的に decrement (同入力で同回数)。
- 連鎖は max_chain で必ず bounded (無限ループしない)。超過は faults に記録 (silent 飲み込みなし)。
- rumination 0 / 未設定は one-shot (後方互換)。
- guard 発動後も状態整合 (残 reservation は drop、scheduler 整合維持)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| trigger rumination | N+1 回発火、decrement | 無限/誤回数 | rumination=2 → 3 fire、4 回目 0 |
| reservation rumination | resolve で N 回 reschedule | 再 schedule 漏れ | rumination=2 reservation が 2 回 reschedule、count 0..2 |
| cycle guard | steps<=max_chain、超過で chain_limit fault | 無限ループ / silent | 暴走連鎖 → fired<=max_chain + fault 記録 |
| guard 後状態 | crash せず継続 | 状態破壊 | fault 後 engine が使用可能 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| rumination 0 | one-shot | EQM-061 互換 | — | rumination 0 で 1 fire |
| chain 超過 | drop + `chain_limit` fault | 無限ループ防止・明示 | — | 暴走 cascade で fault |
| follow_up 無効/空 | 連鎖終了 | 自然終端 | — | follow_up なしで 1 step |
