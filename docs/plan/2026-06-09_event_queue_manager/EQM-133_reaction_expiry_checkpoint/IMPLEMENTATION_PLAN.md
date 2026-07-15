# EQM-133 IMPLEMENTATION_PLAN — reaction-expiry checkpoint

## Scope

EQM-132後のcheckpoint監査で見つかった、count終了後のlive expiryをschema v5が復元できないseamを修復する。schema v6の独立ownershipとexact one-event runtime boundaryを追加し、既存resolution意味は維持する。

## Target files

- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd`
- `addons/event_queue_manager/runtime/eq_save_adapter.gd`
- `addons/event_queue_manager/runtime/eq_error.gd`
- `test_project/tests/trigger/test_eq_reaction_fire_context.gd`
- `test_project/tests/transaction/test_eq_snapshot_v2.gd`
- snapshot/API/error/manual/coverage docs

## Steps

1. live `_expiry_by_event`をevent-id順にserializeする`reaction_expiries` tableを追加する。
2. scheduler／armed／expiry tableのbijectionとreservation revisionをverify-before-mutateで検証する。
3. v6 loadでexpiry reservationを先に一度だけ生成し、armed rowから同じinstanceを参照する。
4. v1-v5のstill-armed migrationとhistorical orphan rejectionを固定する。
5. full pipelineを1 scheduler eventだけ処理するpublic result boundaryを追加し、`resolve_next()`を互換wrapperにする。
6. exhausted two-FIRE save/load continuation、tamper rejection、one-event boundaryをtestする。
7. API goldenを明示更新し、`./tools/test.sh`とself-reviewを完了する。

## Dependency / Test Matrix

| area | risk | proof |
|---|---|---|
| snapshot identity | armed消失後にexpiry予約を失う | two FIRE→save/load→FIRE/FIRE/expiry continuation equality |
| migration | historical stateを捏造する | v5 armed succeeds / v5 orphan rejects before mutation |
| table correctness | duplicate、status forge、missing table | stable error tamper tests |
| boundary | expiry callが次reservationまで消費する | handler count + pending event id |
| compatibility | `resolve_next()` order drift | full existing suite and goldens |
