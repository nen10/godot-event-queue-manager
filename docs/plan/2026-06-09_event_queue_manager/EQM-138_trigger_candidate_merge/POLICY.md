# EQM-138 POLICY — sorted derived buckets and linear merge

## Adopted decisions

- canonical truthは`EQTriggerEngine._armed`。index bucketは非serializeの派生状態。
- `_by_target[target]`と`_wildcard`は常にarm sequence昇順を維持する。
- normal armは末尾sequenceが小さいためfast append。condition mutationで古いslotを
  populated bucketへ移す場合だけbinary-search ordered insertionを行う。
- `candidates()`は空/単一bucketでも内部Arrayを返さずfresh Arrayを返す。
- mixed target/wildcardは二本のsorted ArrayをO(t+w)でstable mergeする。sequenceは
  slotごとに一意で、tie policyの追加は不要。
- performance比較用legacy concat+sort helperはtest file内だけに置き、productionへ残さない。

## Compatibility / determinism

- fired occurrence、rumination count、expiry、disarm、condition signal bindingは不変。
- public API、API golden、snapshot schema、trace/goldenは不変。
- algorithmic hard gateはexact candidate sequence/order/count。elapsed speedupは環境付きadvisory。
- 通常回帰はperformance fixtureをdiscoverせず、performance commandはperformanceだけを走らせる。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| per-query full sort | remove | bucket不変条件を隠してhot pathをO(c log c)にする | immediate | legacy parity + no production sort audit |
| unordered append on rebucket | remove | older sequenceをdestination末尾へ置く | immediate | populated target/wildcard retarget |
| persistent merged cache | do not add | invalidation surfaceが大きい | future profile only | n/a |

## State / Invariant proof

ordered insertionはsequence値だけを比較し、reservation/condition/statusを変更しない。
removeは既存どおり一slotだけを消し、残りのsorted orderを保存する。clearは全derived stateと
sequence counterを同時にresetする。
