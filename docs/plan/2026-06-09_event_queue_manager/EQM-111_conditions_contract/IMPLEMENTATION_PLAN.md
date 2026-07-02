# EQM-111 IMPLEMENTATION_PLAN — conditions 契約実装

## Scope

SEM §5.4/§5.5/§5.6 の contract 実装 (coverage rows: conditions-contract, named-predicate-registry)。pipeline 統合 (EQM-113) はしない。

## 変更対象ファイル

- `addons/event_queue_manager/resources/eq_condition_spec.gd` (new) — EQConditionSpec
- `addons/event_queue_manager/runtime/eq_condition_eval.gd` (new) — EQConditionEval (bind / term / solve / invalidation / decide)
- `addons/event_queue_manager/resources/eq_action_definition.gd` — solve/invalidation_conditions + normalized_conditions()
- `addons/event_queue_manager/runtime/eq_runtime.gd` — named predicate registry
- `addons/event_queue_manager/runtime/eq_error.gd`, `docs/design/ERROR_CONTRACT.md` — +5 codes
- `tools/check_api_surface.py`, `docs/design/API_SURFACE.md`, `tests/golden/api_surface.json` — L2 追加 (明示 --update)
- `test_project/tests/resource/test_eq_condition_spec.gd` (new), `test_project/tests/trigger/test_eq_condition_eval.gd` (new)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` — 2 rows flip

## 実装 steps

1. EQConditionSpec (validate / to_dict / from_dict)。
2. EQConditionEval (bind: relative→絶対, COUNTER→counter line 束縛; Result/Outcome; fault は値返し)。
3. EQActionDefinition 拡張 (typed array export + 入れ子 validate + normalized_conditions)。
4. EQRuntime predicate registry (register/has/predicates)。
5. codes + ERROR_CONTRACT。
6. tests → `./tools/test.sh`。
7. API surface 再 baseline (--update-golden api_surface) + docs。
8. coverage flip → queue proof → self-review → commit。

## Test path

`./tools/test.sh` (新規 2 test file を含め green)。golden 更新は api_surface のみ (明示 flag、self-review 記載)。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| 入れ子 Resource の .tres roundtrip | 型情報喪失 | roundtrip test (typed array 復元) |
| 評価器 ↔ SEM §5.4 | level/AND/OR/勝敗の取り違え | 同時成立・ctx 変化再評価・順序固定 test |
| API surface | 未 tag class で gate FAIL | LAYER_MAP + docs + --update の三点同時 |
| coverage gate | flip 漏れ (COMPLETE なのに reserved) | checker が FAIL するため commit 前に flip |

## Completion checklist (planned)

- [ ] 2 新規 class + 拡張 + registry + codes + tests
- [ ] `./tools/test.sh` PASS / api-surface ok / contract-coverage ok
- [ ] coverage rows flip / queue proof / self-review / commit
