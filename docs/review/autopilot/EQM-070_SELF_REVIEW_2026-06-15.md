# EQM-070 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct — foundational transaction model). Repair: 0.

## Execution summary

Implemented `EQTransaction`, a player-turn draft transaction over a scheduler using a working-copy model. At begin it saves the live snapshot and clones a working copy; draft operations touch only the working copy, so the live scheduler is unchanged until commit; rollback resets the working copy to base; commit promotes the working copy to live. Built on EQM-012 snapshot/restore + EQM-033 `EQSnapshot.equals` (eq_snapshot.gd unchanged — the existing API sufficed).

## Changed files

- `addons/event_queue_manager/runtime/eq_transaction.gd` — `EQTransaction` (L2): draft_push/draft_cancel, working/draft/is_live_unchanged, rollback/commit/is_committed.
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQTransaction: L2`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/transaction/test_eq_transaction.gd` (new dir).

## Acceptance result — met

| acceptance | result |
|---|---|
| draft actions can be applied | draft_push/draft_cancel apply to the working copy |
| inspected | `working()` (draft scheduler) + `draft()` (recorded ops) |
| rolled back | rollback restores the working copy to base and clears the draft log |
| committed | commit promotes the working copy to live (live gains the drafted event, correctly ordered) |
| live scheduler unchanged before commit | `is_live_unchanged()` true through drafting/rollback; `live.size()` reflects only seeded events until commit |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=30 checks=388 failures=0; [api-surface] ok
```

## Design notes (no shrink)

- **Working-copy, not snapshot-on-live**: drafting on a clone keeps the live scheduler untouched until commit, which is exactly the "unchanged before commit" guarantee. Rollback is "reset the clone"; commit is "promote the clone." Both reuse the EQM-012/033 snapshot primitives — no new serialization.
- **L2**: transactions are part of the deep player-turn machinery (the Action Resolution wait-commit, EQM-071); simple L0/L1 turn-order does not require them.
- Wait/end-turn commit + ready-reservation scheduling is deliberately EQM-071; deterministic replay is EQM-072 — kept out of this task's boundary.

## UX path reduction

- Added: `EQTransaction` (L2). Narrowed: drafts go through draft_push/draft_cancel on the working copy (live is never touched mid-draft). Residual: none.

## Deviations

- `eq_snapshot.gd` listed as a target but not modified — the existing snapshot/restore/equals API was sufficient. Recorded.

## Repair-now / follow-up

None. Next: EQM-071 (wait/end-turn commit boundary) — player immediate actions are rollbackable before wait; wait commits the draft and schedules the ready reservation (wires EQTransaction to EQActionResolutionPolicy). Kept orchestrator-direct.
