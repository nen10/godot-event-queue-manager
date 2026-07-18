# EQM-142 — Scheduler live-peek fast path — SUB_TASKS

## Complexity

Class: C4
Reason:
- Runtime performance hot path that affects the scheduler, trace `decided_by`, and binary-heap viability.
- Must preserve deterministic ordering and golden trace bytes while changing internal work shape.
- Requires both regression and independent performance-lane proof.

Required artifacts:
- SUB_TASKS.md
- UX.md
- POLICY.md
- IMPLEMENTATION_PLAN.md

## Task resolution candidate matrix

| candidate | goal / UX | decision | reason |
|---|---|---|---|
| A. Change `EQScheduler.peek_next()` to call `peek_min()` first | Remove full-backend copy in normal live-min case | Adopt | Minimal public/API impact; preserves existing call sites and trace contract. |
| B. Add a separate `peek_next_fast()` and update callers | Avoid behavior risk in existing API | Reject | Duplicates API paths and leaves consumer callers on slow path. |
| C. Add backend iterator API | Avoid copy and support stale scan | Defer | Larger backend contract change; EQM-142 can solve the dominant no-stale path without it. |
| D. Eagerly purge stale entries inside `peek_next()` | Avoid fallback scan when stale-front | Reject for this task | Mutates from a peek API; would alter lazy-invalidation semantics and may perturb trace/debug expectations. |

## Scheduled Task Audit

No new scheduled task is required beyond the already queued Phase 15 chain:

| existing task | relation to EQM-142 | action |
|---|---|---|
| EQM-143 | reschedule O(1) accelerator | Keep as dependent follow-up. |
| EQM-144 | public `has_event()` membership | Keep as later API task. |
| EQM-145 | backend selection | Keep dependent on EQM-142 so heap exposure is safe. |

## Task resolution

Implement candidate A. `peek_next()` keeps the same public behavior and return type. It first inspects `_backend.peek_min()`. If that entry is live, it returns it without `ordered()`; if not live (cancelled/rescheduled stale-front), it falls back to the existing ordered live scan. The fallback is intentionally retained as a semantic mirror for rare stale-front cases and will be reassessed only if profiling proves stale-front dominates.
