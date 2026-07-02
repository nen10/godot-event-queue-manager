# EQM-117 IMPLEMENTATION_PLAN — snapshot v2 + save 境界 enforcement

## Scope

SEM §10 実装 (coverage row: snapshot-v2 + save-enforcement)。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_save_adapter.gd` (v2 bundle / gate / migrator / pipeline 委譲)
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (+save_state / verify_state / apply_state)
- `addons/event_queue_manager/runtime/eq_event_lines.gd` (+restore_values — sweep rule 登録と trace を保持した instance 復元)
- `addons/event_queue_manager/runtime/eq_trigger_engine.gd` (+armed_entries 読み出し)
- `addons/event_queue_manager/resources/eq_condition.gd` (+to_dict/from_dict — custom_predicate 除外)
- `addons/event_queue_manager/runtime/eq_error.gd` + `docs/design/ERROR_CONTRACT.md` (+eqm.save.blocked)
- `docs/design/SNAPSHOT_COMPAT_V1.md` (v2 追記)
- `test_project/tests/transaction/test_eq_snapshot_v2.gd` (new)
- surface golden (明示 --update) / coverage flip / queue / self-review

## 実装 steps

1. EQCondition serialize → engine 読み出し → lines 復元 → pipeline save/verify/apply → adapter v2 + gate。
2. tests (gate / v2 roundtrip 継続同一性 / v1 migrator / 未知 version / 未登録名 verify / live object 不含)。
3. `./tools/test.sh` → surface --update → coverage flip → compat doc → queue → self-review → commit。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| 既存 v1 save 利用者 (EQM-085 tests) | adapter 変更での退行 | 既存 save/load tests green (v1 受理) |
| verify-before-mutate | 半 load | 失敗 load 後の runtime 無変更 test |
| counter/gid 決定性 | 復元後の id 再利用 | counter_seq 継続 (既存 test) |

## Completion checklist (planned)

- [ ] v2 bundle + gate + verify-load + 復元 / tests green / 互換 doc / surface ok / coverage flip / queue / self-review / commit
