# EQM-142 — Scheduler live-peek fast path — POLICY

## Adopted decisions

- `EQScheduler.peek_next()` is the canonical fast path. Callers should not need to opt in.
- A live backend minimum is sufficient to answer `peek_next()` because `EQOrdering` is total and the scheduler's liveness check only filters stale generations.
- Stale-front remains a fallback to the existing ordered live scan; peek remains non-mutating.

## Rejected decisions

- Do not purge stale backend entries in `peek_next()`.
- Do not remove `trace.decided_by` or weaken explanation data for speed.
- Do not expose backend selection in this task.

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| stale-front fallback to `ordered()` scan | Keep | Preserves lazy invalidation and correct next live entry when min is stale | Only remove if backend contract gains non-mutating live iterator/purge semantics | cancel-min and reschedule-min tests |
| existing `ordered()` snapshot path | Keep | Required for `peek(n)` and snapshot until later tasks | Not in EQM-142 scope | existing scheduler/snapshot tests |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| backend min | if live, it is the next live entry | wrong trace next comparison | new core test with mixed ordering |
| stale backend entries | never returned by `peek_next()` | cancelled/rescheduled event leaks | cancel-min/reschedule-min tests |
| trace `decided_by` | byte-identical for equivalent event queues | golden churn | `./tools/test.sh` golden gate |
| performance suite | advisory elapsed separate from correctness | false performance claim | `./tools/test.sh --performance` with deterministic work counters |
