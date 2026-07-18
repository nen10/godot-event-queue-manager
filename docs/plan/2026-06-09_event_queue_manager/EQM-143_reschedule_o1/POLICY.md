# EQM-143 — Reschedule O(1) live-entry map — POLICY

## Adopted decisions

- `_generation` remains the source of truth for live ids/generations.
- `_live_entries` is a private derived accelerator: key set must equal `_generation` key set.
- Restore rebuilds the accelerator from validated live snapshot entries.

## Rejected decisions

- Do not make backend responsible for event identity.
- Do not purge stale backend artifacts during reschedule.
- Do not change snapshot schema; stale backend entries remain non-serializable implementation detail.

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| stale backend artifacts | Keep | Lazy invalidation keeps cancel/reschedule cheap | Separate compaction task with evidence | existing cancel/reschedule + new map tests |
| `_generation` + `_live_entries` mirror | Keep private | fast lookup without API change | never public; can be replaced by better internal index | push/pop/cancel/reschedule/restore invariant tests |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `_generation` | live event ids and generation numbers | stale id marked live | existing scheduler tests |
| `_live_entries` | same key set as `_generation`, current entry per id | wrong payload/kind copied on reschedule | new reschedule preserves metadata test |
| backend | may contain stale entries | stale surfaced by peek/pop | existing lazy invalidation tests + EQM-142 stale tests |
| restore | accelerator rebuilt only after validation | partial mutation on malformed snapshot | existing snapshot tests |
