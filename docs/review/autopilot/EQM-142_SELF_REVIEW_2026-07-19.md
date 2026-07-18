# EQM-142 Self Review — Scheduler live-peek fast path

Date: 2026-07-19 (Asia/Tokyo)
Status: COMPLETE

## Summary

EQM-142 removes the dominant trace-peek hot path identified in the scheduler performance investigation. `EQScheduler.peek_next()` now answers from `backend.peek_min()` when the minimum entry is live, avoiding a full `ordered()` copy/sort on every event resolution. Stale-front cases keep the old ordered scan as a non-mutating fallback, preserving lazy invalidation semantics.

## Changed files

- `addons/event_queue_manager/runtime/eq_scheduler.gd`
- `test_project/tests/core/test_eq_scheduler_live_peek.gd`
- `test_project/tests/performance/test_eq_scheduler_live_peek.gd`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- `docs/plan/2026-06-09_event_queue_manager/EQM-142_scheduler_live_peek/{SUB_TASKS,UX,POLICY,IMPLEMENTATION_PLAN}.md`
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md`

## Acceptance result

| acceptance | result | proof |
|---|---|---|
| `peek_next()` uses O(1) backend min when live | PASS | counting backend reports zero `ordered()` calls in live-min and steady-state drain tests |
| stale-front fallback preserved | PASS | cancel-front and reschedule-front tests return the correct next live entry |
| legacy behavior parity | PASS | test-only copy of old ordered scan returns the same event in mixed cancel/reschedule scenario |
| trace/golden unchanged | PASS | full `./tools/test.sh` passed |
| independent performance evidence | PASS | performance fixture hard-gates 511 legacy ordered calls / 130,816 copied entries → 0 current ordered calls / 0 entries |

## Tests

- `./tools/test.sh` → PASS
  - run id: `20260719-041732-35719`
  - suite: regression
  - files: 77
  - checks: 2081
  - failures: 0
- `./tools/test.sh --performance` → PASS
  - run id: `20260719-041804-36685`
  - suite: performance
  - files: 6
  - checks: 56
  - failures: 0
  - EQM-142 advisory: heap drain N=512, current 6,051 usec, legacy 301,161 usec, 49.77x; hard work 130,816 copied/sorted entries → 0

## Deviation record

No scope deviations. Backend selection remains deferred to EQM-145 as planned.

## Repair-now audit

No repair-now items remain.

## Scheduled task audit

No new scheduled tasks were created during EQM-142. Existing Phase 15 tasks remain:

- EQM-143 reschedule O(1)
- EQM-144 `has_event()` membership API
- EQM-145 backend selection / consumer docs

## Completion judgment

COMPLETE. EQM-142 satisfies the performance hard gate and preserves correctness/determinism. EQM-143 is now ready by dependency sweep.
