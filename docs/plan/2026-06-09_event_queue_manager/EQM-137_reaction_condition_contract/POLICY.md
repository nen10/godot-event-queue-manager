# EQM-137 POLICY — fail-closed trigger input boundary

## Adopted decisions

- `reaction_condition`のaccepted型は`EQCondition | null`のみ。
- `EQReservationRuntime.submit()`がstructured faultの唯一の権威。型検査はreservation自身の
  validation直後、actor/effect/meta/status/index/scheduler mutationより前に行う。
- wrong typeは`eqm.reaction.condition_type_invalid`で拒否し、fresh reservationを変更しない。
- `EQTriggerEngine.arm()`はbool、`EQTriggerIndex.add()`はsequenceまたは`-1`を返し、直接
  callerでもinvalid inputを副作用なしに拒否する。low-level層はruntime faultを重複生成しない。
- pre-submit rejectionは`reservation_rejected` traceで記録する。架空のevent idを持つ
  `invalid_event_skipped`へ偽装しない。

## Rejected decisions

- `EQConditionSpec`を`EQCondition`へ暗黙変換しない。
- transient `custom_predicate`をnamed registryから暗黙rebindしない。
- invalid reservationをARMED後に巻き戻す実装にしない。mutation前に拒否する。
- shipped modeでsilent skipしない。

## Compatibility stance

誤型acceptanceは`provisional_unused`ではなく未定義動作であり、互換対象にしない。正常な
`EQCondition|null` caller、snapshot schema、正常trace、fired orderは維持する。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| duck-typed condition fallback | remove | roleの異なるResourceを受けるfalse greenを生む | immediate | wrong-type submit/arm/index rejection |
| `EQConditionSpec` trigger mirror | do not add | solve/invalidation contractとの二重の真実になる | n/a | resource role assertions + EBS integration proof |
| transient callable spatial trigger | keep only as documented transient option | saveを跨がない直接用途は既存契約 | durable named-trigger需要が確定した場合に別設計 | existing EQCondition tests |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| wrong type before submit | status=PENDING、event_id=-1、effect binding=-1、issued meta未bind | ghost arm / partial issue | dev+shipped mutation audit |
| engine/index | invalid input consumes no arm sequence、bucket、signal binding | later order shift | direct engine/index rejection + next valid sequence=0 |
| valid input | arm order、condition matching、rumination、expiry unchanged | regression | existing trigger lifecycle/full regression |
| shipped anomaly | fault + rejection trace、halted=false、next valid reaction works | silent failure / poisoned runtime | shipped continuation test |
| dev anomaly | fault + rejection trace、halted=true | anomaly hidden | dev test |
