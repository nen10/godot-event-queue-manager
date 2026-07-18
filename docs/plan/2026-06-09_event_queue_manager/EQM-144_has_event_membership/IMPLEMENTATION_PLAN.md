# EQM-144 — Scheduler has_event membership API — IMPLEMENTATION_PLAN

## Scope

- Add `EQScheduler.has_event(event_id: int) -> bool`.
- Replace internal membership-only `peek(size())` scans in reservation intervention and snapshot-restore reconciliation.
- Add scheduler tests for live/cancel/pop/reschedule states.
- Add/adjust reservation tests if needed to confirm unchanged rejection semantics.
- Update API surface docs and golden.
- Update performance profile ledger.

## Target files

- `addons/event_queue_manager/runtime/eq_scheduler.gd`
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd`
- `test_project/tests/core/test_eq_scheduler_reschedule_o1.gd` or new scheduler test
- `docs/design/API_SURFACE.md`
- `docs/ja/design/API_SURFACE.md`
- `tests/golden/api_surface.json`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- `docs/review/autopilot/EQM-144_SELF_REVIEW_2026-07-19.md`

## Steps

1. Add `has_event()` to scheduler.
2. Replace membership-only scans.
3. Add tests for has_event liveness states and no-ordered membership path.
4. Update API surface docs and golden (`tools/check_api_surface.py --update`).
5. Run regression and performance suites.
6. Self-review, queue update, commit.

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| scheduler liveness | stale entry reported live | core has_event tests |
| reservation runtime | intervention rejection changes | existing reservation tests |
| API surface | layer leak | API surface golden/checker |
| performance separation | no performance fixture needed | performance suite unchanged must PASS |

## Completion checklist

- [ ] `has_event()` implemented and documented.
- [ ] internal membership scans removed.
- [ ] API golden updated.
- [ ] regression PASS.
- [ ] performance PASS.
