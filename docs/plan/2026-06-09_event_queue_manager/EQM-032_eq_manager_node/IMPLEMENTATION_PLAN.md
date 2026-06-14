# EQM-032 IMPLEMENTATION_PLAN

## Scope

EQManager Node (6 signal + driver 契約 + policy 自動委譲) と plugin 登録を実装する。production node bridge (save/load rebind 等) は EQM-085。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_manager.gd` — `EQManager extends Node`。
- `addons/event_queue_manager/plugin.gd` — add_custom_type("EQManager", ...) / remove。
- `docs/design/EVENT_MODEL_SEMANTICS.md` — §14 driver/await を EQManager 実 API に整合 (step/finish_action/advance_frame/suspend)。
- `tools/check_api_surface.py` — LAYER_MAP に `EQManager: L0`。
- `docs/design/API_SURFACE.md` — L0 表に追記。
- `tests/golden/api_surface.json` — `--update` 再 baseline。
- `test_project/tests/runtime/test_eq_manager.gd` — signal flow / suspend / frame-budget determinism / invalid policy。

## 実装 steps

1. EQManager: configure/set_policy/register_actor/seed/validate/step/finish_action/advance_frame + 6 signal + `_awaiting_turn`。
2. plugin.gd 登録。
3. SEMANTICS §14 整合。
4. LAYER_MAP + API_SURFACE.md。
5. test (runtime dir 新規)。
6. `python3 tools/check_api_surface.py --update`。
7. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (runtime/integration): signal 契約 + suspend + frame-budget determinism + invalid policy。node-bridge save/load は EQM-085。
- §4 gate (API surface): EQManager L0、leak なし。
- 期待: 既存 206 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQRuntime (EQM-022) | wrap で mode/trace 崩れ | manager trace == runtime trace (正常) |
| policy 契約 (EQM-030/031) | 自動委譲ミス | finish_action→policy.on_turn_finished で次 turn |
| RUNTIME_RESILIENCE | budget で順序破壊 | budget=1 vs N で trace byte 一致 |
| Godot Node/signal | headless で動かない | bare Node で signal emit/connect、tree 不要 |
| API surface gate | 無断 surface 変更 | 明示 --update、L0、self-review に diff |

## Completion checklist

- [ ] 6 signal を正しい payload/順序で emit。
- [ ] suspend: turn_ready 後 step()=null、finish で再開。
- [ ] advance_frame: budget 不変で同 trace (determinism)。
- [ ] invalid policy config を validate で捕捉。
- [ ] plugin に EQManager custom type 登録。
- [ ] driver 契約を SEMANTICS §14 に整合。
- [ ] EQManager L0、golden 明示更新、self-review に diff。
- [ ] `./tools/test.sh` PASS。
