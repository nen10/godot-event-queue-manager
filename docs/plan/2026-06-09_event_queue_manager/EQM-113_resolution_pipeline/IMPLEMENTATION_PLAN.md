# EQM-113 IMPLEMENTATION_PLAN — 解決 pipeline 統合

## Scope

SEM §6.1–§6.3/§13 の実装 (coverage rows: resolution-pipeline, reaction-schedule, expiry-event, invalidate-actor)。snapshot v2 (117)・authoring 受け入れ (.tres 基準, 119) はしない。

## 変更対象ファイル

- `runtime/eq_reservation_runtime.gd` — pipeline 再構成 (lines/chunk/engine 所有、submit 束縛、resolve_next 5-step、step_tick、invalidate_actor L2)
- `runtime/eq_runtime.gd` — effect registry + invalidate_actor (L0) + `event_invalidated` trace
- `runtime/eq_trigger_engine.gd` — fire_cascade/max_chain 削除、disarm/disarm_for 追加、expired 観測可能化
- `resources/eq_action_definition.gd` — `priority` / `effect_name` / `expiry_effect_name` (additive)
- `runtime/eq_node_bridge.gd` — on_actor_freed → invalidate_actor
- `runtime/eq_error.gd` + `docs/design/ERROR_CONTRACT.md` — `eqm.effect.unregistered`
- `docs/design/EVENT_MODEL_SEMANTICS.md` §11 — trace kinds `event_invalidated` / `reaction_fired` を additive 追記
- tests: `tests/core/test_eq_resolution_pipeline.gd` (new), `tests/trigger/test_eq_reaction_pipeline.gd` (new), `tests/trigger/test_eq_rumination_cycle_guard.gd` (新契約へ更新)
- `tools/check_api_surface.py` 不変 / golden 再 baseline (surface diff: +field/+method/−fire_cascade)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` — 4 rows flip

## 実装 steps

1. EQActionDefinition fields → EQError code → ERROR_CONTRACT。
2. EQRuntime: effect registry / invalidate_actor / trace。
3. EQTriggerEngine: 削除 + disarm + expired。
4. EQReservationRuntime pipeline (最大工程)。
5. bridge 配線。
6. tests (新 2 + cycle guard 更新) → `./tools/test.sh`。
7. SEM §11 追記 / surface --update / coverage flip / queue / self-review / commit。

## Test path

`./tools/test.sh`。golden 更新は api_surface のみ (明示)。ordering/trace golden は不変のはず — demo/dogfood は L0/L1 経路のため。変化した場合は原因を特定し self-review 記載の上で明示更新。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| 既存 EQM-051/052 挙動 | pipeline 再構成での退行 | 既存 test_eq_reservation_runtime / action_resolution 系 green |
| EQM-062 受け入れの継承 | cycle guard 消失 | cycle guard test を pipeline round guard へ書き換え |
| L3 leak | EQRuntime 署名への露出 | api-surface leak gate |
| trace 決定性 | 新 kind の非決定 field | jsonl 検証 + 既存 golden 不変 |
| dev/shipped 二相 | invalidate_actor の mode 分岐混入 | 両 mode 同一 trace test |

## Completion checklist (planned)

- [ ] pipeline + registry + expiry + invalidate_actor + bridge
- [ ] 新 tests green / 既存 tests green (cycle guard 更新含む)
- [ ] SEM §11 追記 / surface ok / coverage 4 rows flip
- [ ] queue proof / self-review / commit
