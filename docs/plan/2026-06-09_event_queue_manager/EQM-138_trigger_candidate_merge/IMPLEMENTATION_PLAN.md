# EQM-138 IMPLEMENTATION PLAN — stable trigger candidate merge

## Scope

target bucket + wildcard bucketの候補構築からper-sweep full sortを除き、sorted derived
bucketのlinear mergeへ置き換える。mutation後を含むglobal arm orderを厳密に維持する。

## Target files

- `addons/event_queue_manager/runtime/eq_trigger_index.gd`
- `test_project/tests/trigger/test_eq_trigger_engine_index_lifecycle.gd`
- `test_project/tests/trigger/test_eq_trigger_index.gd`
- `test_project/tests/performance/test_eq_trigger_engine_candidate_work.gd`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- queue/self-review/test inventory

## Implementation steps

1. bucket insertionをfast append + binary-search ordered insertへ変更する。
2. candidatesをempty/single/mixedのfresh Array + two-way mergeへ変更する。
3. target-only/wildcard-only/mixedとpopulated destination retargetをexact orderで固定する。
4. performance laneへsparse 7.5% / wildcard-heavy約27.5% fixtureを置く。
5. performance-only legacy sort assemblerとのoutput parityと同一process elapsed A/Bを記録する。
6. full regression、independent performance、API/trace/snapshot auditを実行する。
7. self-review、runtime profile、queue proofを更新してcommitする。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| unique arm sequence | merge tie ambiguity | index valid-after-invalid + duplicate slot lifecycle |
| condition.changed rebucket | destination disorder | older seq → populated target/wildcard exact order |
| shared condition slots | multi-slot rebucket disorder | shared condition + interleaved destination regression |
| candidate ownership | returned alias mutation | single-bucket copy regression |
| production engine | index-only benchmark false confidence | match-call/fired/armed hard gates through engine |
| elapsed evidence | noisy ratio | warmup + repeated batches; ratio report only, no hard threshold |
| lane separation | speed test enters regression | explicit discovery counts from both commands |

## Completion checklist

- [x] Production candidate assembly contains no full candidate sort.
- [x] Every bucket stays sequence-sorted across add/remove/retarget/clear.
- [x] Exact candidate/fired order matches legacy behavior in all declared cases.
- [x] Sparse and wildcard-heavy performance results are recorded independently.
- [x] Regression and performance commands pass; API/schema/trace remain unchanged.
- [x] Self-review has no repair-now item and queue dependency sweep is updated.
