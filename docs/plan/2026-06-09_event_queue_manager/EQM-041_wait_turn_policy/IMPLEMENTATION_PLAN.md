# EQM-041 IMPLEMENTATION_PLAN

## Scope

EQWaitTurnPolicy + wait-turn demo + demo golden を実装する。reducibility は EQM-053。

## 変更対象ファイル

- `addons/event_queue_manager/resources/policies/eq_wait_turn_policy.gd` — `EQWaitTurnPolicy`。
- `tools/check_api_surface.py` — LAYER_MAP に `EQWaitTurnPolicy: L1`。
- `docs/design/API_SURFACE.md` — L1 表に追記。
- `tests/golden/api_surface.json` — `--update`。
- `demos/wait_turn_tactics/{wait_turn.gd,wait_turn.tscn,README.md}` — learning-path demo。
- `tests/golden/demo_wait_turn.trace.jsonl` — demo golden (`--update-golden demo_wait_turn`)。
- `test_project/tests/policy/test_eq_wait_turn_policy.gd` — instant resolve / cost / equal-wait tie-break。
- `test_project/tests/debug_scene/test_wait_turn_demo.gd` — demo headless golden 比較。

## 実装 steps

1. EQWaitTurnPolicy (seed: due_tick=wait, priority=agility; on_turn_finished: next_wait=cost)。
2. LAYER_MAP + API_SURFACE.md。
3. policy test + demo + demo golden test。
4. `python3 tools/check_api_surface.py --update`、`./tools/test.sh --update-golden demo_wait_turn`。
5. 通常 `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (policy): instant resolve / cost / tie-break。
- §4 gate (demo): headless golden。
- §4 gate (API surface): EQWaitTurnPolicy L1。
- 期待: 既存 241 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQPolicy 契約 (EQM-030) | 契約逸脱 | seed/on_turn_finished のみ |
| EQOrdering (EQM-010) | tie 非決定 | equal wait = agility→sequence |
| DETERMINISM §5 (demo golden) | 非決定 demo | golden exact 比較 |
| API surface gate | 無断変更 | 明示 --update、L1 |

## Completion checklist

- [ ] instant resolve: min wait 先、current_tick jump。
- [ ] action cost が次 wait を決める (heavy→後)。
- [ ] equal wait tie-break 説明 + test (agility→登録順)。
- [ ] wait-turn demo + golden、learning-path 明記。
- [ ] EQWaitTurnPolicy L1、golden 明示更新。
- [ ] `./tools/test.sh` PASS。
