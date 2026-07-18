# EQM-143 — Reschedule O(1) live-entry map — SUB_TASKS

## Complexity

Class: C4
Reason:
- Scheduler state accelerator touches push/pop/cancel/reschedule/restore invariants.
- Fixes a documented O(1) claim that was false in implementation.
- Needs regression, snapshot, and performance-lane proof.

Required artifacts:
- SUB_TASKS.md
- UX.md
- POLICY.md
- IMPLEMENTATION_PLAN.md

## Task resolution candidate matrix

| candidate | goal / UX | decision | reason |
|---|---|---|---|
| A. Maintain event_id→live EQEntry map in scheduler | True O(1) `_find_live` | Adopt | Smallest change that makes docstring and behavior align. |
| B. Ask backend to find by event_id | Push identity responsibility into backend | Reject | Violates backend contract; liveness is scheduler-owned. |
| C. Compact backend on every reschedule | Avoid stale entries | Reject | Makes reschedule O(n) and changes lazy invalidation cost boundary. |
| D. Wait for EQM-144 `has_event` only | Membership O(1) but not entry lookup | Reject | Does not solve preserving kind/actor/payload on reschedule. |

## Scheduled Task Audit

No new scheduled tasks. EQM-144 and EQM-145 remain existing follow-ups.

## Task resolution

Implement candidate A. `_live_entries` mirrors `_generation` for live ids, storing the current live `EQEntry` object for each event id. The backend still owns ordered storage and may contain stale entries. `_generation` remains the authoritative liveness key for `_is_live`; `_live_entries` is an accelerator and is rebuilt from snapshot restore entries.
