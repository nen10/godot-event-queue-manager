# EQM-145 — Scheduler backend selection — POLICY

## Adopted decisions

- Backend selection is Resource/API (`EQConfig`) and setup-time only.
- `SORTED_ARRAY = 0` is the default and migration value.
- `BINARY_HEAP = 1` is explicit opt-in for large queues after EQM-142/143 removed the trace/reschedule full-sort bottlenecks.
- Unknown backend values are stable config errors.
- Non-empty scheduler backend replacement is rejected with a stable runtime fault.

## Rejected decisions

- No automatic backend switching.
- No live scheduler migration in this task.
- No snapshot schema change: backend selection is config, not scheduler state.

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| sorted-array default | Keep | compatibility and small queue simplicity | major version / explicit roadmap | default config test |
| heap opt-in | Add | large queue performance path | N/A | config/runtime/backend parity tests |
| non-empty configure rejection | Stable fault, keep scheduler | avoids destructive replacement | future explicit migration task | manager/runtime tests |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `EQConfig.scheduler_backend` | only known enum values are valid | unknown value silently falls back | validation test |
| runtime scheduler | backend replaced only while empty | live events lost | non-empty rejection test |
| ordering | both backends produce same sequence/trace | heap parity bug | metamorphic test |
| snapshot | no schema change | save compat drift | snapshot docs and regression |
