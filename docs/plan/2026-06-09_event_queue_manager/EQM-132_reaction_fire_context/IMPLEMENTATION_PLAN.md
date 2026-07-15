# EQM-132 IMPLEMENTATION_PLAN — reaction fire occurrence context v1

## Scope

FIRE occurrence の cause を versioned value として trigger sweep から effect callback、inspection、trace、save/load まで運び、armed lifecycle と scheduled FIRE lifecycle を分離する。

## Target files

- `addons/event_queue_manager/runtime/eq_reaction_fire_context.gd`
- `addons/event_queue_manager/runtime/eq_trigger_engine.gd`
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd`
- `addons/event_queue_manager/runtime/eq_save_adapter.gd`
- `addons/event_queue_manager/runtime/eq_error.gd`
- `test_project/tests/trigger/`, `test_project/tests/transaction/`
- snapshot/API/error docs and completion review

## Steps

1. context v1 builder/validator/deep-copy contractを追加する。
2. trigger engine に occurrence API を追加し、legacy API はその projection とする。
3. pipeline が fired reservation を複製して schedule し、context を event id に bind する。
4. single/bundle/expiry sweep に exact triggering scheduler event id と view index を渡す。
5. handler/inspection/trace へ context を投影し、cancel/invalidate/restore cleanup を網羅する。
6. save schema を更新し、new-schema required context と historical context-less pending FIRE rejectionを検証する。
7. targeted tests、全 `./tools/test.sh`、self-review を行う。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| trigger engine rumination | fire index off-by-one | max two: index 1/2, third absent |
| reservation aliasing | ARMED status/expiry corruption | queue two FIRE occurrences before resolve; instances/event ids distinct |
| typed effect callback | cause not delivered or mutable | exact context + mutation isolation |
| snapshot | cause lost/rebound to wrong event | save/load continuation and trace equality |
| schema compatibility | silent context loss | v5 validation + historical pending-FIRE rejection |
| ordering | context detached by order hook | simultaneous reaction ordering test |

## Completion checklist

- context is versioned, JSON-safe, and game-vocabulary-neutral.
- armed and FIRE_PENDING instances are distinct.
- handler, inspection, trace, save/load agree on occurrence identity.
- no count/cost coupling is introduced.
- targeted and full tests pass; self-review has no repair-now item.
