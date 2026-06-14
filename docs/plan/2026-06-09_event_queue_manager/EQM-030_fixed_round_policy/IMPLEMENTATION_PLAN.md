# EQM-030 IMPLEMENTATION_PLAN

## Scope

EQPolicy 契約 (seed/on_turn_finished) と EQFixedRoundPolicy を実装する。runtime 自動委譲は EQM-032。

## 変更対象ファイル

- `addons/event_queue_manager/resources/policies/eq_policy.gd` — 契約メソッド `seed` / `on_turn_finished` (no-op base) を追加。
- `addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd` — `EQFixedRoundPolicy`。
- `tools/check_api_surface.py` — LAYER_MAP に `EQFixedRoundPolicy: L1`。
- `docs/design/API_SURFACE.md` — L1 表に追記。
- `tests/golden/api_surface.json` — `--update` で再 baseline (EQPolicy +2 method, +EQFixedRoundPolicy)。
- `test_project/tests/policy/test_eq_fixed_round_policy.gd` — battle-start / round refresh / equal-initiative / removal skip。

## 実装 steps

1. EQPolicy に seed/on_turn_finished (no-op) 追加。
2. EQFixedRoundPolicy 実装。
3. LAYER_MAP + API_SURFACE.md 追記。
4. policy test 作成。
5. `python3 tools/check_api_surface.py --update` で golden 再 baseline (surface 変更を承認、self-review に diff)。
6. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (policy): 順序契約 (battle-start/round/tie/removal)。golden trace は demo (EQM-034) で。
- §4 gate (API surface): EQFixedRoundPolicy が L1 に登録、leak なし、golden 一致。
- `./tools/test.sh` 期待: 既存 191 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQRuntime primitives (EQM-022) | policy が内部依存 | policy は schedule/advance/registry のみ使用 |
| EQOrdering (EQM-010) | tie 非決定 | 同 initiative=登録順 |
| EQActorState.data (EQM-021) | initiative source 不整合 | data[initiative_key] から読む |
| API surface gate (EQM-023) | 無断 surface 変更 | golden を明示 --update、L1 leak なし、self-review に diff |

## Completion checklist

- [ ] EQPolicy 契約 (seed/on_turn_finished) 追加、base no-op。
- [ ] EQFixedRoundPolicy: battle-start=initiative DESC、round refresh、equal-initiative=登録順、removal skip。
- [ ] EQFixedRoundPolicy が L1 (LAYER_MAP + API_SURFACE.md)、leak なし。
- [ ] api_surface golden を明示 --update、self-review に diff 記載。
- [ ] `./tools/test.sh` PASS。
