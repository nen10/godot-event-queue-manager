# EQM-144 — Scheduler has_event membership API — UX

## User goal

Addon consumers and EQM internals can ask whether a scheduled event is still live without allocating a full queue snapshot or scanning `peek(size())` results.

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---:|---:|---|---|
| `has_event(id)` boolean | High | Low | Low | Adopt | Simple, stable, no mutation boundary. |
| `find_event(id)` returns entry | Medium | Medium | Medium | Defer | Would require copy-vs-reference policy. |
| Continue `peek(size()).any(...)` docs | Low | Medium | Low | Reject | Encourages slow path and exposes internal queue traversal. |

## Experience steps

1. Consumer stores an event id returned by `schedule()` / `push()`.
2. Consumer calls `scheduler.has_event(event_id)` before acting on that id.
3. The result is true only while the event is live; cancelled, popped, or superseded stale entries are false.

## Maintained UX

- Existing `peek(n)` remains available for ordered previews.
- Existing reservation intervention rejection semantics remain unchanged.
