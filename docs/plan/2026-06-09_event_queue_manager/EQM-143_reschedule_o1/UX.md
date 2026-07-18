# EQM-143 — Reschedule O(1) live-entry map — UX

## User goal

Games that frequently reschedule events (CTB, energy, wait-turn, action-resolution delay adjustments) avoid a hidden full-queue scan while observing the same event order and snapshot behavior.

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---:|---:|---|---|
| Transparent internal accelerator | High | Medium | Medium | Adopt | No consumer code changes and corrects documented performance contract. |
| New explicit `reschedule_fast` API | Low | High | Medium | Reject | Splits the API into two correctness paths. |
| Backend-specific acceleration only | Medium | High | Medium | Reject | Would make behavior dependent on backend internals. |

## Experience steps

1. Consumer calls `reschedule()` directly or via policies as before.
2. The event retains id/kind/actor/payload and receives a fresh sequence/generation as before.
3. Internally the scheduler locates the current live event by id without copying/sorting the backend.

## Maintained UX

- Same `reschedule()` API and return values.
- Same lazy invalidation and trace order.
- Same snapshot/restore public shape.
