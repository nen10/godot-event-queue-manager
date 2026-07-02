# EQM-115 IMPLEMENTATION_PLAN — ordering hook

## Scope

SEM §7.1 の順序 hook (coverage row: ordering-hook)。composite bundle はしない (defer)。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (+set_order_hook / 2 適用点 / view 構築 / permutation 検証 / trace)
- `addons/event_queue_manager/runtime/eq_error.gd` + `docs/design/ERROR_CONTRACT.md` (+1 code)
- `test_project/tests/core/test_eq_order_hook.gd` (new)
- surface golden (明示 --update) / coverage flip / queue / self-review

## 実装 steps

1. code 追加 → hook 保持 + `_order_candidates` helper → 2 適用点へ配線。
2. tests (既定発行順 / 並べ替え / 不正 permutation / view serializable / fired にも適用 / 2-run byte 同一)。
3. `./tools/test.sh` → surface --update → coverage flip → queue → self-review → commit。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| §3 comparator 不変 | hook の越権 | 既存 ordering/policy tests 不変 green |
| hook 未設定既定 | v1.0 退行 | 既定 = 発行順 test |
| trace 決定性 | 配列 field の非決定 | 2-run byte 同一 test |

## Completion checklist (planned)

- [ ] hook + 2 適用点 + 検証 + trace / tests green / surface ok / coverage flip / queue / self-review / commit
