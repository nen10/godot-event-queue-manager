# EQM-140 IMPLEMENTATION PLAN — sparse event-line polling

## Scope

poll selectionをall-lines sort/filterからlive watched-key sortへ変え、effective rateをcanonical
modifier stateから再構築可能なprivate cacheでO(1) lookupする。

## Target files

- `addons/event_queue_manager/runtime/eq_event_lines.gd`
- `test_project/tests/core/test_eq_event_lines.gd`
- `test_project/tests/performance/test_eq_event_line_budget.gd`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- queue/self-review/test inventory

## Implementation steps

1. private effective-rate calculate/refresh/rebuild helperとcacheを追加する。
2. construction/issue/re-rate/modifier add/remove/restoreへcache同期を接続する。
3. `effective_rate_of`とpollをcache lookupへ変更する。
4. watched keysからexisting canonical idsだけをcontent-sortするprivate selectorを追加する。
5. modifier遷移、zero/negative、watched挿入順、unknown、in-place restoreを回帰で固定する。
6. performance laneで旧all-line selectorと旧modifier scanのexact parity、work count、elapsed A/Bを記録する。
7. full regression、independent performance、API/snapshot/trace auditを実行する。
8. self-review、runtime profile、queue proofを更新してcommitする。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| line issue/re-rate | missing/stale cache | base/add/override transition exact values |
| modifier order | latest override drift | non-last/latest removal + restore array order |
| invalid operations | cache/seq mutation | next valid id and effective value unchanged |
| poll selection | watched/issue insertion order drift | reversed orders + exact trace bytes |
| zero/negative effective | incorrect skip/advance | base+add zero、override zero、negative poll |
| in-place restore | old keys/cache/trace leakage | old line removal + immediate remove/re-rate/poll |
| snapshot/API | derived cache leakage | exact `to_dict` and API golden |
| elapsed evidence | noisy/unfair legacy path | counter-free exact old helpers + alternating samples |
| lane separation | speed test enters regression | explicit discovery counts from both commands |

## Completion checklist

- [x] Production polling enumerates watched keys, not all line ids.
- [x] Effective-rate reads are cache lookups synchronized at every mutation boundary.
- [x] Exact values/trace/order/snapshot match legacy behavior.
- [x] Deterministic work reduction and advisory A/B are recorded independently.
- [x] Regression and performance commands pass.
- [x] Self-review has no repair-now item and queue dependency sweep is updated.
