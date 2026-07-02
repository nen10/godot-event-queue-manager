# EQM-114 IMPLEMENTATION_PLAN — window object model

## Scope

SEM §8.1/§9 実装 (coverage row: window-object-model)。save 配線 (EQM-117)・EQManager 統合 (不採用 G) はしない。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_window.gd` (new, L2)
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (+window stack / open・close / deadline 検査 / is_save_boundary)
- `addons/event_queue_manager/runtime/eq_error.gd` + `docs/design/ERROR_CONTRACT.md` (+4 codes)
- `test_project/tests/transaction/test_eq_window.gd` (new)
- `tools/check_api_surface.py` / `docs/design/API_SURFACE.md` / golden (明示 --update)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` (1 row flip)

## 実装 steps

1. EQWindow → codes → stack/open/close/deadline 検査 → is_save_boundary。
2. tests → `./tools/test.sh` (demo golden 不変を含む)。
3. surface --update → coverage flip → queue → self-review → commit。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQTransaction 互換 | 従属化での退行 | 既存 transaction tests 不変 green |
| L0 golden | root trace 混入 | test.sh の demo golden 一致 |
| pipeline 統合 | deadline 検査点の漏れ | resolve_next / step_tick 両経路の test |
| commit clobber | pop 済み event 復活 | conflict test |

## Completion checklist (planned)

- [ ] EQWindow + stack + budget + deadline + traces + guard
- [ ] tests green (既存含む) / surface ok / coverage flip / queue / self-review / commit
