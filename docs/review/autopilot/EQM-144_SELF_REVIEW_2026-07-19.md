# EQM-144 Self Review — Scheduler has_event membership API

Date: 2026-07-19 (Asia/Tokyo)
Status: COMPLETE

## Summary

EQM-144 adds `EQScheduler.has_event(event_id)` as an O(1) membership API backed by the scheduler generation map. Internal membership-only scans in reservation intervention and snapshot-restore reconciliation now use `has_event()` instead of `peek(size())` full queue copies. Ordered `peek(n)` remains for preview UX.

## Changed files

- `addons/event_queue_manager/runtime/eq_scheduler.gd`
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd`
- `test_project/tests/core/test_eq_scheduler_has_event.gd`
- `docs/design/API_SURFACE.md`
- `docs/ja/design/API_SURFACE.md`
- `tests/golden/api_surface.json`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- `docs/plan/2026-06-09_event_queue_manager/EQM-144_has_event_membership/{SUB_TASKS,UX,POLICY,IMPLEMENTATION_PLAN}.md`
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md`

## Acceptance result

| acceptance | result | proof |
|---|---|---|
| public `has_event(id)->bool` reports scheduler liveness | PASS | tests cover push/reschedule/pop/cancel/restore |
| stale backend artifacts are invisible | PASS | cancelled event remains in backend but `has_event` returns false |
| internal membership scans removed | PASS | reservation intervention and restore reconciliation use direct `has_event`; remaining `peek(size())` is actor-filter scan in `invalidate_actor`, not membership-only |
| API surface golden updated deliberately | PASS | `tools/check_api_surface.py --update` adds only `EQScheduler.has_event(event_id: int) -> bool` |
| consumer docs note migration | PASS | EN/JA API_SURFACE notes tell Amberground/consumers to replace `peek(size())` membership scans with `has_event()` |

## Tests

- `python3 tools/check_api_surface.py --update` → PASS
  - golden diff: one additive `EQScheduler.has_event(event_id: int) -> bool`
- `./tools/test.sh` → PASS
  - run id: `20260719-042623-43002`
  - suite: regression
  - files: 79
  - checks: 2116
  - failures: 0
- `./tools/test.sh --performance` → PASS
  - run id: `20260719-042629-43163`
  - suite: performance
  - files: 7
  - checks: 64
  - failures: 0

## Deviation record

No scope deviations. `_reconcile_runtime_state_after_snapshot_restore()` was implemented as per-key `has_event()` checks rather than constructing a partial live-id dictionary, preserving the original semantics for map keys that are live in the scheduler even if not present in `_by_event`.

## Repair-now audit

No repair-now items remain.

## Scheduled task audit

No new scheduled tasks were created during EQM-144. EQM-145 remains the backend-selection follow-up and will add the larger consumer-facing API note.

## Completion judgment

COMPLETE. EQM-144 satisfies the API and internal hot-path requirements and keeps the Phase 15 queue moving to EQM-145.
