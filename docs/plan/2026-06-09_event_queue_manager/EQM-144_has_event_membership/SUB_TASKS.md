# EQM-144 — Scheduler has_event membership API — SUB_TASKS

## Complexity

Class: C3
Reason:
- Adds a small public L0 API and replaces internal full-copy membership scans.
- Requires API surface golden/doc update and regression proof.
- Performance impact is deterministic work reduction, but scope is narrower than EQM-142/143.

Required artifacts:
- SUB_TASKS.md
- UX.md
- POLICY.md
- IMPLEMENTATION_PLAN.md

## Task resolution candidate matrix

| candidate | goal / UX | decision | reason |
|---|---|---|---|
| A. Add `EQScheduler.has_event(event_id)` | O(1) public membership check | Adopt | Useful for consumers and internal runtime; mirrors scheduler liveness source. |
| B. Keep API private and only patch internal scans | Avoid API surface change | Reject | User explicitly asked docs/API notes for consumer awareness; membership is broadly useful. |
| C. Expose `get_event(event_id)` | Direct event access | Defer | Higher API responsibility (copy/mutation boundaries) not needed for membership. |

## Scheduled Task Audit

No new scheduled tasks. EQM-145 remains existing backend-selection follow-up.

## Task resolution

Implement candidate A. `has_event()` returns whether an event id is currently live according to `_generation`. It does not inspect backend storage and does not expose stale artifacts. Replace internal `peek(size())` membership scans that only need existence.
