# EQM-021 IMPLEMENTATION_PLAN

## Scope

actor state / action result / registry の public API を実装する。実 weak-binding rebind (save/load) は EQM-085。policy 別の cost/delay 意味論は Phase 3+。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_error.gd` — 新 code 5 つを append (actor.duplicate_id/id_reused/empty_id, action.negative_delay/negative_cost)。
- `addons/event_queue_manager/runtime/eq_actor_state.gd` — `EQActorState`。
- `addons/event_queue_manager/runtime/eq_action_result.gd` — `EQActionResult`。
- `addons/event_queue_manager/runtime/eq_actor_registry.gd` — `EQActorRegistry`。
- `docs/design/ERROR_CONTRACT.md` — code 表に 5 行追記。
- `test_project/tests/resource/test_eq_actor_registry.gd` — registration/duplicate/reuse/empty/weak-binding。
- `test_project/tests/resource/test_eq_action_result.gd` — cost/delay validation。

## 実装 steps

1. EQError に 5 code を append + ERROR_CONTRACT.md 追記。
2. EQActorState (identity + data + weak binding + to_dict/from_dict)。
3. EQActionResult (cost/delay/allow_negative_cost + validate)。
4. EQActorRegistry (register/validate_register/unregister/... + retired 追跡)。
5. tests。
6. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (resource/API): registration/duplicate/reuse rejection + weak-binding + action validation。
- `./tools/test.sh` 期待: 既存 132 + 新 checks 全 pass、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQM-020 EQError/EQValidation | code 不整合 | 新 5 code の recoverability/severity assert |
| semantics §13/Q10 (actor_id 再利用禁止) | identity 衝突 | unregister→register が id_reused |
| Adapter 原則 (Node 参照不混入) | save に live ref 漏洩 | to_dict に binding 無し; freed→null |
| semantics §12 (数値域) | 負値の扱い不整合 | negative_delay 常時不正、negative_cost は allow で切替 |
| EQM-020 tie_break=&"actor_id" totality | id 非一意で順序非決定 | registry の一意/不再利用が裏付け |

## Completion checklist

- [ ] register: 成功で EQActorState、重複/再利用/空で null + 対応 code。
- [ ] actor_id 再利用拒否 (retired 追跡)。
- [ ] weak binding placeholder: bind/bound/is_bound、freed→null、to_dict に出ない。
- [ ] EQActionResult.validate: negative_delay 常時、negative_cost は allow_negative_cost で切替、valid は issue 空。
- [ ] 新 5 code が ERROR_CONTRACT.md と EQError に存在。
- [ ] `./tools/test.sh` PASS。
