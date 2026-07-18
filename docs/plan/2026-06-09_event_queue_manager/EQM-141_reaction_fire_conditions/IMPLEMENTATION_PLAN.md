# EQM-141 IMPLEMENTATION PLAN — reaction FIRE conditions

## Scope

EQCondition candidate match後・rumination mutation前にdefinition solve/invalidationを評価する
preview/commit境界を追加し、arm-time bindとschema-v8 continuationを完成させる。

## Target files

- `runtime/eq_trigger_engine.gd`
- `runtime/eq_reservation_runtime.gd`
- `runtime/eq_save_adapter.gd`
- reaction/condition/snapshot tests and API golden
- event semantics, snapshot/manual/error/API docs
- EBS bridge/acceptance/docs/dependency proof (consumer-owned)

## Implementation steps

1. trigger engineへnon-mutating previewとchecked commit/invalidateを追加し、既存APIをwrapper化する。
2. reaction conditionsのreference preflight、arm-time bind、private gate lifecycleを追加する。
3. sweepでpreview→gate decision→commitを行い、accepted FIREだけscheduleする。
4. declared COUNTER progressionとduration/actor/count closure cleanupを接続する。
5. schema v8 save/verify/applyとhistorical migration rejectionを追加する。
6. false→true、invalidation-wins、counter、fault、multi-view、save/loadの厳密回帰を追加する。
7. EBS R04をmatcher + named spatial solveの実FIRE acceptanceへ戻す。
8. regression/performance/consumer/package gates、self-review、queue proof、commitを完了する。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| trigger index | previewで候補順drift | arm-order/mixed target parity |
| rumination | WAIT/tie/schedule fault/duplicate slotで先行・共有消費 | exact slot remaining/status/cardinality + cascade/context/actor failure |
| named predicate | wrong view/transient Callable | composite deep-copy view + registration/load |
| COUNTER | reissue/alias/double decrement/solve deadlock | provenance/namespace/id/count/tamper + solve rejection |
| expiry/actor departure | private gate leak / post-arm duration drift | duration/invalidate_actor/condition/count cleanup + stale expiry roundtrip + watched set |
| scheduled FIRE | duplicate gate evaluation | predicate call count and pending occurrence |
| snapshot v8 | bind anchor/definition edit/counter provenance/slot lifecycle drift | exact roundtrip + post-arm condition/duration/rumination edit + shape/range/alias tamper + historical cases |
| API surface | accidental public drift | explicit golden update for preview/commit only |
| EBS consumer | ARM-only false green | false produces no FIRE; later true produces exactly one |
| lane separation | performance fixture in regression | both commands/discovery counts |

## Completion checklist

- [x] preview/commit gate is atomic and deterministic
- [x] arm-time bound gate covers named predicates, lines, counters
- [x] schema v8 continuation is exact and verified before mutation
- [x] EQM full gates and EBS consumer gates pass
- [x] self-review/queue/proof/docs/commit complete
