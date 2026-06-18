# EQM-102 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — order-identity is correctness-core; kept P0 rather than delegated). Repair: 0.

## Execution summary

Added the binary-heap backend (`EQBinaryHeapBackend`, core) and the trigger index
(`EQTriggerIndex`, L2), with budgets declared before benchmarking. The heap is
order-identical to the sorted-array backend (proven entry-for-entry on 5000 entries)
and opt-in via `EQScheduler.new(EQBinaryHeapBackend.new())` — no public API change,
no golden change to existing traces. The index returns the same fired set + arm order
as the linear `EQTriggerEngine` while reconsidering only the target bucket + wildcards.

## Changed files

- `addons/event_queue_manager/runtime/backends/eq_binary_heap_backend.gd` (new — core).
- `addons/event_queue_manager/runtime/eq_trigger_index.gd` (new — L2).
- `test_project/tests/performance/test_eq_binary_heap_backend.gd`, `test_eq_trigger_index.gd` (new).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` (+EQBinaryHeapBackend core, +EQTriggerIndex L2).
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`): +2 classes. Additive.

## Declared budgets (before benchmarking — SUB_TASKS.md)

```text
actor_count 2000 · event_count 20000 · heap 10k insert+pop < 2000 ms (regression guard)
order correctness: heap pop sequence == sorted-array, entry-for-entry on 5000 events (hard gate)
trigger index: candidates(view) << total armed, same fired set + arm order as linear
```

## Acceptance result — met

| acceptance | result |
|---|---|
| numeric budgets declared before benchmarking | SUB_TASKS.md §"Declared performance budgets" + test header constants (ORDER_N, BUDGET_N/MS, M) |
| large queue benchmark judged against budgets with order correctness | heap pop sequence == sorted-array sequence entry-for-entry on 5000 events (hard pass); 10000 insert+pop within the 2000 ms guard |
| backend selectable without public API break | `EQScheduler.new(EQBinaryHeapBackend.new())` swaps storage; the scheduler's public API is unchanged; default stays sorted-array so existing traces/goldens are untouched |
| trigger indexing | `EQTriggerIndex` buckets by match_target (+wildcard); parity test asserts indexed fired == linear reference == real `EQTriggerEngine`; candidate set a strict subset of all armed |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=48 checks=658 failures=0
  heap order-identity (5000), throughput budget, scheduler-swap, ordered() non-mutating: green
  trigger-index parity (vs linear + real engine) + candidate-subset + wildcard: green
  [api-surface] ok (golden re-baselined: +EQBinaryHeapBackend, +EQTriggerIndex)
```

## Design notes (no shrink)

- **Order-identity is the hard gate, and it is real.** The heap is compared against
  the sorted-array backend entry-for-entry over 5000 entries with many tick/priority
  ties; they match because both use `EQOrdering.less_than` and sequence is unique
  (total order, no stability ambiguity). This is why kept P0 rather than delegated —
  a subtly wrong heap silently corrupts every schedule.
- **`ordered()` is non-mutating** (sorts a copy) — a heap array is only partially
  ordered, so a naive "return the array" would be wrong; tested explicitly (heap size
  unchanged after two `ordered()` calls, result in EQOrdering order).
- **No API break, no golden churn.** The default backend is unchanged, so the
  scheduler's public surface and every existing demo/core golden trace are identical;
  the heap is purely additive and opt-in. The api-surface gate confirms (only the two
  new classes added).
- **The index is a candidate filter, not a re-implementation of matching.**
  `match_target` is the bucket key; `condition.matches()` still does the full check
  (tags/kind/source) — so the index can never fire something the engine wouldn't. An
  empty `match_target` is a wildcard (matches() agrees), held in a wildcard bucket and
  returned for every view; tested. Parity is checked against the REAL engine, not just
  a reference, so the speedup cannot diverge from correctness.

## UX path reduction

- Added: `EQBinaryHeapBackend` (core), `EQTriggerIndex` (L2). Narrowed: nothing —
  both are opt-in accelerators behind existing contracts. Residual: wiring the index
  INTO `EQTriggerEngine` (so callers get it transparently) is deferred; the standalone
  index + parity proof is the EQM-102 deliverable, integration is a clean follow-up.

## Deviations

- Kept P0 (orchestrator-direct) despite flagging it a Codex candidate earlier — the
  order-identity property is correctness-core, so certainty outweighed offloading.

## Repair-now / follow-up

None. Next: EQM-103 (release candidate) — the final task. **STOP before any external
AssetLib upload** (§8.4): packaging/version/changelog/license + a release proof are
in scope; publishing to an external registry is not, and needs explicit user action.
