# EQM-144 — Scheduler has_event membership API — POLICY

## Adopted decisions

- `has_event(event_id)` is an L0 scheduler API.
- Liveness means `_generation.has(event_id)`, not backend containment.
- Stale cancelled/rescheduled backend artifacts are intentionally invisible.

## Rejected decisions

- Do not expose current `EQEntry` by id in this task.
- Do not change `peek(n)` semantics or snapshot compaction.

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| old `peek(size())` membership pattern | Remove from EQM internals | Full-copy scan with no ordering need | N/A | reservation/runtime tests + grep audit |
| `peek(n)` public preview path | Keep | Ordered preview remains valid UX | N/A | existing tests |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `_generation` | key exists iff event is live | stale artifact misreported | has_event tests for push/cancel/pop/reschedule |
| reservation intervention | rejects absent scheduler target with same reason | semantic drift | existing and new intervention tests |
| API docs/golden | new L0 method documented | consumer misses migration | API_SURFACE + JA update, golden update |
