# EQM-040 IMPLEMENTATION_PLAN

## Scope

EQEnergyPolicy を EQM-030 契約上に実装。reducibility は EQM-053。

## 変更対象ファイル

- `addons/event_queue_manager/resources/policies/eq_energy_policy.gd` — `EQEnergyPolicy`。
- `tools/check_api_surface.py` — LAYER_MAP に `EQEnergyPolicy: L1`。
- `docs/design/API_SURFACE.md` — L1 表に追記。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/policy/test_eq_energy_policy.gd` — readiness / cost / speed / wait / carry-over。

## 実装 steps

1. EQEnergyPolicy: speed_key/threshold/base_cost、_arm (delay + energy_at_turn)、seed、on_turn_finished (carry)。
2. LAYER_MAP + API_SURFACE.md。
3. test。
4. `python3 tools/check_api_surface.py --update`。
5. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (policy): readiness/cost/speed/wait/carry-over。
- §4 gate (API surface): EQEnergyPolicy L1。
- 期待: 既存 234 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQPolicy 契約 (EQM-030) | 契約逸脱 | seed/on_turn_finished のみ |
| semantics §12 | float 混入 | delay int ceil |
| EQActorState.data | speed/energy source | data 経由 |
| API surface gate | 無断変更 | 明示 --update、L1 |

## Completion checklist

- [ ] threshold readiness (seed = ceil(threshold/speed))。
- [ ] action cost: heavy>normal>wait の次 delay。
- [ ] speed 差で行動頻度。
- [ ] carry-over: cheap 後の delay 短縮。
- [ ] EQEnergyPolicy L1、golden 明示更新、self-review に diff。
- [ ] `./tools/test.sh` PASS。
