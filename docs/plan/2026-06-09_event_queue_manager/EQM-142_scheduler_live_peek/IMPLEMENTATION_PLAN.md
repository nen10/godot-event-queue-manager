# EQM-142 — Scheduler live-peek fast path — IMPLEMENTATION_PLAN

## Scope

- Update `EQScheduler.peek_next()` to use `_backend.peek_min()` when the min entry is live.
- Add core scheduler tests for live-min fast path and stale-front fallback behavior.
- Add an independent performance fixture that proves no-stale live-peek work avoids full `ordered()` copy/sort and records advisory elapsed.
- Update `docs/design/RUNTIME_PERFORMANCE_PROFILE.md` with EQM-142 evidence and residual ledger status.

## Target files

- `addons/event_queue_manager/runtime/eq_scheduler.gd`
- `test_project/tests/core/test_eq_scheduler.gd` or nearby scheduler tests
- `test_project/tests/performance/test_eq_scheduler_live_peek.gd`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md`
- `docs/review/autopilot/EQM-142_SELF_REVIEW_2026-07-19.md`

## Steps

1. Implement the `peek_min()` fast path with existing ordered fallback.
2. Add a test-only counting backend to assert fast path does not call `ordered()` when min is live.
3. Cover empty, single, mixed, cancel-min stale-front, and reschedule-min stale-front.
4. Add performance-lane fixture comparing a legacy copy of the old implementation with current `peek_next()` using a binary heap and sorted backend.
5. Update runtime performance profile and queue proof.
6. Run `./tools/test.sh` and `./tools/test.sh --performance`.
7. Self-review and commit `autopilot(EQM-142): ...`.

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| scheduler liveness | stale min returned | core scheduler tests |
| trace determinism | `decided_by` changes | full regression/golden gate |
| performance separation | elapsed used as sole proof | performance fixture includes deterministic `ordered()` call count |
| EQM-145 backend exposure | heap still slow | EQM-142 performance evidence becomes precondition |

## Completion checklist

- [ ] `peek_next()` no-stale path uses `peek_min()` and zero `ordered()` calls in test.
- [ ] stale-front fallback returns correct live event.
- [ ] regression PASS.
- [ ] performance PASS.
- [ ] runtime performance profile updated.
- [ ] self-review created.
