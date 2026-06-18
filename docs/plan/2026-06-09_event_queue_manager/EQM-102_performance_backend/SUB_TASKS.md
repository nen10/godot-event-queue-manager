# EQM-102 SUB_TASKS

## Complexity

Class: C4 (orchestrator-direct — order-identity is correctness-core). Repair: 0.
Reason: a backend whose pop order is not byte-identical to the sorted-array backend
would silently corrupt every schedule. The heap must honor the same total order.

## Declared performance budgets (BEFORE benchmarking — acceptance)

```text
actor_count budget        : 2000 actors registered + scheduled
event_count budget        : 20000 live events held by a backend
per-advance cost (heap)    : insert + pop_min are O(log n); a 10000-insert then
                             10000-pop cycle completes < 2000 ms headless (regression guard)
order correctness          : heap pop sequence == sorted-array pop sequence, entry-for-entry,
                             on a deterministic 5000-event sequence (the hard gate; wall-clock is advisory)
trigger index             : candidates(view) for a selective target returns
                             (target bucket + wildcard) << total armed, with the SAME
                             fired set + arm order as the linear engine
```

Rationale: the order-correctness budget is a hard pass/fail (determinism). Wall-clock
is a coarse regression guard (headless timing varies); it is generous so it fails only
on an algorithmic regression (e.g. an accidental O(n) path), not on machine noise.

## Task Resolution

| candidate | adopt | note |
|---|---|---|
| `runtime/backends/eq_binary_heap_backend.gd` (EQBinaryHeapBackend, core) | yes | min-heap by EQOrdering.less_than; all 7 EQBackend methods; `ordered()` = non-mutating sorted copy |
| `runtime/eq_trigger_index.gd` (EQTriggerIndex, core) | yes | bucket armed reactions by `match_target` (+ wildcard); `candidates(view)` in arm order; parity-tested vs linear scan |
| `tests/performance/` benchmarks | yes | order-identity (heap == sorted) + wall-clock guard + trigger-index parity |
| backend selection | unchanged | `EQScheduler.new(EQBinaryHeapBackend.new())` — opt-in; default stays sorted-array (no public API break, no golden change) |

## Scheduled Task Audit

Next: EQM-103 (release candidate). No new scheduled task.
