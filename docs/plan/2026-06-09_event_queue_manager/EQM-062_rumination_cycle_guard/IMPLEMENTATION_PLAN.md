# EQM-062 IMPLEMENTATION_PLAN

## Scope

rumination (再武装/再 schedule) と cycle guard (max_chain) を実装する。window nest budget 統合は §8 narrow (defer)。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_error.gd` — `eqm.trigger.chain_limit` (BUDGET_EXCEEDED) append。
- `addons/event_queue_manager/runtime/eq_trigger_engine.gd` — fire 時 rumination 再武装 + `max_chain`/`faults`/`fire_cascade`。
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` — `resolve_next` で rumination 再 submit。
- `docs/design/ERROR_CONTRACT.md` — chain_limit 行追記。
- `tools/check_api_surface.py` / `docs/design/API_SURFACE.md` — EQTriggerEngine surface 更新 (fire_cascade 等)。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/trigger/test_eq_rumination_cycle_guard.gd` — rumination (trigger + reservation) + cycle guard。

## 実装 steps

1. EQError + ERROR_CONTRACT に chain_limit。
2. EQTriggerEngine: on_event_resolved に rumination 再武装、`max_chain`/`faults`/`fire_cascade`。
3. EQReservationRuntime.resolve_next: rumination 再 submit。
4. test。
5. `python3 tools/check_api_surface.py --update`。
6. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (trigger): rumination decrements+reschedules (reservation & reaction)、cycle guard が max_chain で停止 + 明示 chain_limit。
- §4 gate (API surface): EQTriggerEngine 更新、no L3 leak。
- 期待: 既存 358 + 新 checks、api-surface ok、exit 0。EQM-061 の one-shot test が rumination 0 で不変。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQM-061 trigger engine | one-shot 互換崩れ | rumination 0 で 1 fire (既存 test 維持) |
| EQReservation rumination (EQM-050) | 再 schedule 漏れ | remaining_ruminations decrement + reschedule |
| SEMANTICS §8 (bounded round + guard) | 無限ループ / crash | max_chain で bounded、chain_limit fault、crash しない |
| RUNTIME_RESILIENCE (BUDGET_EXCEEDED) | silent 飲み込み | fault に記録 |
| API surface gate | 無断変更 | 明示 --update |

## Completion checklist

- [ ] trigger rumination: N+1 回発火、decrement、0=one-shot。
- [ ] reservation rumination: resolve で N 回 reschedule、count decrement。
- [ ] cycle guard: 暴走連鎖を max_chain で停止 + `chain_limit` fault (crash しない)。
- [ ] chain_limit code が EQError + ERROR_CONTRACT に存在。
- [ ] EQM-061 one-shot test 不変。
- [ ] golden 明示更新、`./tools/test.sh` PASS。
