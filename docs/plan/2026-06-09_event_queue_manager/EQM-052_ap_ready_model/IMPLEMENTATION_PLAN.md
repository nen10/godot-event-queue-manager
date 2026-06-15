# EQM-052 IMPLEMENTATION_PLAN

## Scope

EQActionResolutionPolicy (AP 回復 → ready turn → wait close) を EQPolicy 契約上に実装する。event-line 還元証明は EQM-053。

## 変更対象ファイル

- `addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd` — `EQActionResolutionPolicy` (L2)。
- `tools/check_api_surface.py` — LAYER_MAP に `EQActionResolutionPolicy: L2`。
- `docs/design/API_SURFACE.md` — L2 表に追記。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/policy/test_eq_action_resolution_policy.gd` — ready delay / AP determinism / wait close / ready_reservation_for。

## 実装 steps

1. EQActionResolutionPolicy: ap_key/recovery_key/ap_max/recovery_per_tick/action_ap_cost、_recovery、_recovery_delay、seed、on_turn_finished、ready_reservation_for。
2. LAYER_MAP (L2) + API_SURFACE.md。
3. test。
4. `python3 tools/check_api_surface.py --update`。
5. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (policy): ready after AP recovery delay / AP spend+recovery deterministic / turn closes through wait / ready reservation object。
- §4 gate (API surface): EQActionResolutionPolicy L2、no L3 leak。
- 期待: 既存 308 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQPolicy 契約 (EQM-030) | 契約逸脱 | seed/on_turn_finished のみ |
| EQM-050 READY kind | 予約形不一致 | ready_reservation_for が READY を返す |
| SEMANTICS §4 (event-line) / 行動解決 (COVERAGE 行9) | 意味論逸脱 | AP=進行、ready=AP閾値、wait=close |
| semantics §12 | float 混入 | delay int ceil |
| API surface gate | 無断変更 | 明示 --update、L2、no L3 leak |

## Completion checklist

- [ ] ready reservation が AP 回復 delay 後に turn を grant (seed/turn 後の delay)。
- [ ] AP spend/recovery が決定的 (data[ap]、同入力同 delay)。
- [ ] turn closes through wait (on_turn_finished が次 ready を schedule)。
- [ ] ready_reservation_for が READY 予約 (delay=AP回復) を返す。
- [ ] EQActionResolutionPolicy L2、golden 明示更新、self-review に diff。
- [ ] `./tools/test.sh` PASS。
