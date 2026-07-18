# EQM-142 — Scheduler live-peek fast path — UX

## User goal

A game developer can resolve many queued events without a hidden per-resolution copy/sort cost, especially when using the binary-heap backend in later tasks, while seeing the same event order and trace explanation data.

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---:|---:|---|---|
| Invisible internal speedup | High | Low | Low | Adopt | Existing `advance()` and trace UX remain unchanged. |
| New user-facing fast API | Medium | Medium | Medium | Reject | Users should not have to choose fast vs correct peek. |
| Disable trace `decided_by` next comparison | Medium performance | High product loss | Low | Reject | Deterministic explanation is core product value. |
| Force heap backend now | Medium | High | Medium | Defer | Backend exposure belongs to EQM-145 after live-peek is safe. |

## Experience steps

1. Consumer calls `EQRuntime.advance()` / `EQManager.step()` as before.
2. The resolved trace still records `tie_break.decided_by` using the same next-entry semantics.
3. Large queues avoid an avoidable full ordered copy/sort on each event resolution.
4. No migration or code change is required for EQM-142.

## Maintained UX

- Existing scheduler `peek_next()` API.
- Existing golden trace content/order.
- Existing lazy cancellation/reschedule behavior.

## Deferred UX

- Choosing `binary_heap` through config is deferred to EQM-145 and will be documented for Amberground there.
