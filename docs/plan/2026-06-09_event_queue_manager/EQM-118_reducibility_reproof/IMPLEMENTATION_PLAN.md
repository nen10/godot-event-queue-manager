# EQM-118 IMPLEMENTATION_PLAN — reducibility 再証明

## Scope

SEM §16.1 (coverage row: reducibility-product-proof)。product 変更は submit 時点評価 (SEM §5.4 追記) のみ。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (submit 時点評価)
- `docs/design/EVENT_MODEL_SEMANTICS.md` (§5.4 1 文追記)
- `test_project/tests/policy/test_eq_reducibility_product.gd` (new)
- `test_project/tests/golden/reducibility_ctb_pipeline.trace.jsonl` (new fixture, 明示 --update-golden)
- coverage flip / queue / self-review

## 実装 steps

1. submit 時点評価 → 既存 tests green 確認。
2. product driver (CTB/Energy/Wait-Turn の acceptance loop) + resolved 射影抽出 helper + EQM-053 と同一 matrix の等価 test。
3. golden case `reducibility_ctb_pipeline` を追加し `./tools/test.sh --update-golden reducibility_ctb_pipeline` で初回 baseline。
4. `./tools/test.sh` green → coverage flip → queue → self-review → commit。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| submit 時点評価 | 既存 conditional tests の意味変化 | 既存 tests 無変更 green (全 test は submit 時未成立) |
| 整数演算の同型 | ceil と per-tick の齟齬 | 非約数 speed matrix (EQM-053 と同一) |
| golden | 初回 baseline の手続き | --update-golden + self-review 記録 |

## Completion checklist (planned)

- [ ] 3 model の resolved 部分列一致 (matrix 全 case) / golden baseline / tests green / coverage flip / queue / self-review / commit
