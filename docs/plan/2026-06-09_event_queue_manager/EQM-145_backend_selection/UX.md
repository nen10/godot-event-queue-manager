# EQM-145 — Scheduler backend selection — UX

## User goal

A game developer can choose the binary-heap scheduler backend for large queues through the same project config asset used for policy selection, while small/simple projects retain the sorted-array default with no migration.

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---:|---:|---|---|
| Config enum: sorted default / binary heap opt-in | High | Low | Medium | Adopt | Explicit, serializable, editor-visible. |
| Automatic backend switch | Medium | High | Medium | Reject | Hidden performance behavior and harder debugging. |
| Runtime hot-switch after seeding | Low | High | High | Reject | Live events could be lost or require complex migration. |
| Docs-only recommendation | Low | Low | Low | Reject | No actual consumer path. |

## Experience steps

1. Consumer opens/creates an `EQConfig`.
2. Consumer leaves `scheduler_backend` at `SORTED_ARRAY` for default behavior, or selects `BINARY_HEAP` for large queues.
3. Consumer calls `EQManager.configure(config)` before seeding/scheduling.
4. If configure is attempted after live events exist, EQM records a stable fault and keeps the existing scheduler rather than silently replacing it.

## Maintained UX

- Existing configs default to sorted-array.
- Direct `EQScheduler.new(EQBinaryHeapBackend.new())` remains available for low-level/tests.
- Trace/order remains identical between backends.
