# EQM-143 Self Review — Scheduler reschedule O(1) live-entry lookup

Date: 2026-07-19 (Asia/Tokyo)
Status: COMPLETE

## Summary

EQM-143 makes `EQScheduler.reschedule()` locate the current live event by event id without scanning or copying the backend. A private `_live_entries` accelerator mirrors the existing `_generation` liveness map. `_generation` remains the source of truth; backend storage and lazy stale artifacts are unchanged.

## Changed files

- `addons/event_queue_manager/runtime/eq_scheduler.gd`
- `test_project/tests/core/test_eq_scheduler_reschedule_o1.gd`
- `test_project/tests/performance/test_eq_scheduler_reschedule_o1.gd`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- `docs/plan/2026-06-09_event_queue_manager/EQM-143_reschedule_o1/{SUB_TASKS,UX,POLICY,IMPLEMENTATION_PLAN}.md`
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md`

## Acceptance result

| acceptance | result | proof |
|---|---|---|
| `_find_live()` avoids backend scan | PASS | counting backend reports zero `ordered()` calls for current reschedule |
| push/reschedule/cancel/pop/restore maintain accelerator | PASS | dedicated tests cover reschedule, cancel rejection, popped rejection, restore rebuild, invalid tick non-mutation |
| kind/actor/payload preservation | PASS | core reschedule test asserts preserved metadata |
| trace/snapshot/scheduler semantics unchanged | PASS | full regression passed |
| performance hard gate | PASS | legacy-shape 256 ordered scans / 98,176 entries -> current 0 / 0 |

## Tests

- `./tools/test.sh` → PASS
  - run id: `20260719-042245-41246`
  - suite: regression
  - files: 78
  - checks: 2101
  - failures: 0
- `./tools/test.sh --performance` → PASS
  - run id: `20260719-042251-41408`
  - suite: performance
  - files: 7
  - checks: 64
  - failures: 0
  - EQM-143 advisory: heap reschedule N=256, current 779 usec, legacy-shape 185,047 usec, 237.54x; hard work 98,176 copied/sorted entries -> 0

## Deviation record

No scope deviations. The scheduler class comment was updated to distinguish O(1) target lookup from backend insertion cost (`O(log n)` heap / `O(n)` sorted array), making the old O(1) wording precise.

## Repair-now audit

No repair-now items remain.

## Scheduled task audit

No new scheduled tasks were created during EQM-143. Existing Phase 15 tasks remain:

- EQM-144 public `has_event()` membership API
- EQM-145 backend selection / consumer docs

## Completion judgment

COMPLETE. EQM-143 satisfies acceptance and keeps the Phase 15 queue moving to EQM-144.
