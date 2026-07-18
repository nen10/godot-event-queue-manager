# EQM-143 — Reschedule O(1) live-entry map — IMPLEMENTATION_PLAN

## Scope

- Add private `_live_entries` to `EQScheduler`.
- Maintain it in push/pop/cancel/reschedule/restore.
- Change `_find_live(event_id)` from ordered scan to map lookup.
- Add core tests for zero ordered scans, metadata preservation, cancel/pop/restore map cleanup/rebuild.
- Add performance fixture for current reschedule vs legacy ordered-scan shape.
- Update runtime performance profile and queue proof.

## Target files

- `addons/event_queue_manager/runtime/eq_scheduler.gd`
- `test_project/tests/core/test_eq_scheduler_reschedule_o1.gd`
- `test_project/tests/performance/test_eq_scheduler_reschedule_o1.gd`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md`
- `docs/review/autopilot/EQM-143_SELF_REVIEW_2026-07-19.md`

## Steps

1. Add `_live_entries` and update scheduler state transitions.
2. Implement `_find_live` as map lookup plus generation guard.
3. Test ordinary reschedule without ordered scan and stale cleanup after cancel/pop.
4. Test restore rebuild by rescheduling after restore without ordered scan.
5. Add performance fixture with deterministic ordered-call/entry-count hard gates.
6. Run regression and performance suites.
7. Self-review, queue update, commit.

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| liveness map | desync from generation | core invariant scenarios |
| snapshot restore | missing accelerator rebuild | restore-then-reschedule test |
| trace determinism | sequence/order drift | full regression/golden |
| performance | false elapsed-only claim | performance fixture hard-gates ordered calls/entries |

## Completion checklist

- [ ] `_find_live` performs no backend ordered scan.
- [ ] map stays correct through push/pop/cancel/reschedule/restore.
- [ ] regression PASS.
- [ ] performance PASS.
- [ ] profile + self-review updated.
