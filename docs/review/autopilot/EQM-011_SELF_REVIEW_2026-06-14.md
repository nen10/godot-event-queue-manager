# EQM-011 Self-Review 2026-06-14

Pattern: P0 (linear autopilot, orchestrator-direct). Repair: 1 iteration (test-only type-inference fix; no product-code change).

## Execution summary

Implemented the event scheduler (push/pop/peek/cancel/reschedule) over a swappable `EQBackend` contract. The scheduler owns identity, the insertion sequence, generation-based liveness, and an event-driven clock; the backend owns only ordered storage. Cancel and reschedule are O(1) lazy operations (generation bump only); stale entries are discarded when they surface at pop. Established the `current_tick` / sequence / generation scheduler state that EQM-012 (snapshot) will serialize.

## Changed files

- `addons/event_queue_manager/runtime/backends/eq_backend.gd` — `@abstract class_name EQBackend`: contract (`insert / pop_min / peek_min / ordered / size / is_empty / clear`). Abstract methods → dev fail-fast if a backend forgets one.
- `addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd` — `EQSortedArrayBackend`: sorted insert via `bsearch_custom(EQOrdering.less_than)`, `pop_front` for min. MVP backend.
- `addons/event_queue_manager/runtime/eq_scheduler.gd` — `EQScheduler`: id/sequence assignment, lazy invalidation by `_generation`, non-destructive peek, reschedule = same-id/new-sequence/gen+1, event-driven `current_tick`.
- `test_project/tests/core/test_eq_scheduler.gd` — push/pop order, empty queue, non-destructive peek, lazy cancel, reschedule (+ field preservation + invalid-tick rejection), id/sequence discipline, clock monotonicity.
- `test_project/tests/core/test_eq_backend_contract.gd` — metamorphic: a structurally different `NaiveBackend` (unsorted + scan-for-min) driven through the same scenario yields an identical trace, proving the scheduler depends only on the contract.

## Acceptance result — met

| acceptance | result |
|---|---|
| push/pop | pushes out of order, pops in EQOrdering total order; drained pop → null |
| peek N | `peek_next` / `peek(n)` return live entries in order, non-destructively (size unchanged, next pop unaffected) |
| cancel by event_id | `cancel(id)` true once then false; cancelled id skipped in peek and discarded at pop |
| lazy invalidation/generation | liveness = `_generation[event_id] == entry.generation`; stale entries remain in backend until popped, then discarded |
| reschedule | same id, new due_tick/priority, fresh sequence, gen+1; old entry stale; kind/actor/payload preserved; invalid new tick rejected leaving event unchanged |
| empty queue behavior | pop/peek_next → null, peek(n) → [], cancel/reschedule unknown → false |
| backend behind a language-agnostic swappable contract | `EQBackend` abstract contract; sorted-array and naive backend produce identical scheduler trace (no public API dependence on the implementation) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=4 checks=50 failures=0
```

Classification: `passed`. Gate (§4 core type, DETERMINISM_TRACE_TEST_POLICY): ordering property + metamorphic backend-equivalence checks green. Full golden-trace harness lands in EQM-013.

## Repair record (gate REJECT → fix, attempt 1/3)

- Symptom: parse error in `test_eq_backend_contract._scenario` — `var a := s.push(...)` could not infer type because the `s` parameter was untyped (Variant return). The test.sh masked-failure guard correctly caught it (FAIL despite no assertion failure).
- Fix: typed the parameter `s: EQScheduler`. Test-only change; no product code touched. Re-run green.
- Note: this also confirmed Godot 4.6.2 accepts the `@abstract` class/method syntax — the parse errors were only about the unrelated inference, and `EQBackend` / `NaiveBackend extends EQBackend` compiled.

## Deviations

- None beyond the listed target files. `tests/core/` was split into two files (scheduler behaviour + backend-contract equivalence) — within the queue's `tests/core/` target scope.

## No sample-only completion

All acceptance rests on direct scheduler assertions and a metamorphic two-backend comparison. No bundled sample is involved.

## Repair-now / follow-up

None blocking. `_find_live` and `peek` scan `backend.ordered()` (O(n) copy) — acceptable for the sorted-array MVP and not on a hot path; the EQM-102 binary-heap backend can revisit if profiling warrants. No follow-up task created. Next: EQM-012 (snapshot roundtrip) unblocked — it will serialize `current_tick`, `_next_sequence`, entries, and generations established here.
