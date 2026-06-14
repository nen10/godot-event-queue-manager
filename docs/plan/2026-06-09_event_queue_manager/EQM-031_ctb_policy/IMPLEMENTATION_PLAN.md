# EQM-031 IMPLEMENTATION_PLAN

## Scope

EQCTBPolicy を EQM-030 の契約上に実装する。reducibility (event-line 写像) は EQM-053。

## 変更対象ファイル

- `addons/event_queue_manager/resources/policies/eq_ctb_policy.gd` — `EQCTBPolicy`。
- `tools/check_api_surface.py` — LAYER_MAP に `EQCTBPolicy: L1`。
- `docs/design/API_SURFACE.md` — L1 表に追記。
- `tests/golden/api_surface.json` — `--update` で再 baseline。
- `test_project/tests/policy/test_eq_ctb_policy.gd` — faster extra turns / heavy delay / wait shorter / haste-slow。

## 実装 steps

1. EQCTBPolicy: speed_key/base_cost/scale、delay_of (int ceil)、seed (初期 charge)、on_turn_finished (cost/speed)。
2. LAYER_MAP + API_SURFACE.md。
3. test。
4. `python3 tools/check_api_surface.py --update` (surface 変更承認)。
5. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (policy): 順序/頻度契約。golden trace は demo (EQM-034)。
- §4 gate (API surface): EQCTBPolicy L1、leak なし、golden 一致。
- 期待: 既存 197 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQPolicy 契約 (EQM-030) | 契約逸脱 | seed/on_turn_finished のみで実装 |
| semantics §12 (int域) | float 混入 | delay は int ceil 除算 |
| EQActorState.data (EQM-021) | speed source | data[speed_key] |
| API surface gate (EQM-023) | 無断 surface 変更 | 明示 --update、L1、self-review に diff |

## Completion checklist

- [ ] faster actor extra turns (speed↑で多ターン)。
- [ ] heavy action delay > normal、wait < normal。
- [ ] haste/slow (data[speed] 変更) が次 delay に反映。
- [ ] delay は int>=1、決定的。
- [ ] EQCTBPolicy が L1、golden 明示更新、self-review に diff。
- [ ] `./tools/test.sh` PASS。
