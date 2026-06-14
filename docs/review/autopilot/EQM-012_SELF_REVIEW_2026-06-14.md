# EQM-012 Self-Review 2026-06-14

Pattern: P0 (linear autopilot, orchestrator-direct). Repair: 0 iterations (gate green on first run).

## Execution summary

Added serializable snapshot/restore to the scheduler. `EQSnapshot` owns the wire format (schema version, validation, load result codes); `EQScheduler.snapshot()/restore()` own state capture/apply. Snapshots are plain Dictionaries (no Node references), store only live entries (stale lazy-deletion artifacts are compacted), and carry `schema_version`. Restore validates and rebuilds off to the side before committing, so any non-OK code leaves the scheduler unchanged; the generation map is rebuilt from entries, re-establishing the liveness invariant by construction. Unknown versions return a stable `UNKNOWN_VERSION` code rather than crashing.

## Changed files

- `addons/event_queue_manager/runtime/eq_snapshot.gd` — `EQSnapshot`: `SCHEMA_VERSION=1`, `Load{OK,UNKNOWN_VERSION,MALFORMED}`, `validate(data)` (version checked before structure), `describe(code)`.
- `addons/event_queue_manager/runtime/eq_scheduler.gd` — `snapshot() -> Dictionary` (live entries + current_tick + next_event_id + next_sequence) and `restore(data) -> int` (validate → non-mutating rebuild → commit; generation map rebuilt from entries).
- `test_project/tests/core/test_eq_snapshot.gd` — roundtrip fidelity, stale compaction, post-restore operations (cancel/reschedule/push + counter continuity), unknown-version stable error + unchanged scheduler, malformed (empty/missing-structure/non-dict) error + unchanged scheduler.

## Acceptance result — met

| acceptance | result |
|---|---|
| roundtrip reproduces current_tick | restored `current_tick` equals value at snapshot |
| roundtrip reproduces sequence counter | `next_event_id` / `next_sequence` preserved; a post-restore push continues the id sequence with no collision |
| roundtrip reproduces entries | live entries serialized via `to_dict`/`from_dict` and re-inserted |
| roundtrip reproduces generations | generation rebuilt from each entry (`_generation[event_id] = entry.generation`); post-restore cancel/reschedule target the correct entries |
| roundtrip reproduces subsequent pop order | draining original vs restored yields identical `id:tick` sequences (after a prior pop, a reschedule, and a cancel) |
| snapshot carries `schema_version` | asserted on the snapshot dict |
| unknown versions → stable load error | `schema_version=999` → `UNKNOWN_VERSION` (same code across repeated calls); scheduler unchanged |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=5 checks=74 failures=0
```

Classification: `passed`. Gate (§4 core, DETERMINISM_TRACE_TEST_POLICY): roundtrip/continuity property checks green; the EQM-013 golden harness will add byte-identical trace + snapshot-continuity property tests on top of this contract.

## Design notes (decisions recorded here, not new scope)

- **Live-state compaction**: snapshot stores only live entries. Stale entries left by cancel/reschedule carry no observable semantics; serializing them would leak an implementation detail and is unnecessary for pop-order fidelity. Verified: after a cancel + reschedule, the snapshot holds exactly the live count.
- **Generations rebuilt, not stored separately**: each live entry already carries its generation, and for live entries `_generation[event_id] == entry.generation`. Rebuilding from entries keeps "live event_id set == _generation key set" true by construction and avoids a redundant, desyncable map.
- **Version before structure**: an unknown version may have a different shape, so `validate` checks the version first and only then the v1 structure.

## Deviations

- None beyond the listed target files.

## No sample-only completion

All acceptance rests on direct snapshot/restore assertions; no bundled sample involved.

## Repair-now / follow-up

None blocking. Known limitation (not in this task's acceptance; recorded per plan): a *valid-version* snapshot whose individual entry dict is missing required keys is not exhaustively guarded — `EQEntry.from_dict` uses hard key access. Our restore reaches the entry loop only for version-validated snapshots and returns `MALFORMED` for entries that fail `from_dict`'s tick check, but a structurally broken entry dict (missing `event_id`/`due_tick`) could still error. Full fail-safe of arbitrary inbound data is owned by the EQM-020 error taxonomy and EQM-022 resilience modes; deferred there rather than expanding `eq_entry.gd` scope here. Next: EQM-013 (trace determinism harness) unblocked — it builds golden + property tests on this snapshot-continuity contract.
