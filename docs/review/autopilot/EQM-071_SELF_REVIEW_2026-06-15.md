# EQM-071 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct — wait semantics coupled to the policy). Repair: 0.

## Execution summary

Wired EQTransaction to EQActionResolutionPolicy at the wait/end-turn boundary. A player's immediate actions are drafted (rollbackable before wait); `wait_close` commits the draft to live and then schedules the ready reservation (the next turn after AP recovery). Added a commit-boundary guard so drafting is a no-op after commit.

## Changed files

- `addons/event_queue_manager/runtime/eq_transaction.gd` — `draft_push`/`draft_cancel` are no-ops once committed (boundary guard).
- `addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd` — `wait_close(runtime, actor_id, result, transaction = null)` (commit-then-schedule-ready).
- `tools/check_api_surface.py` (golden) + `docs/design/API_SURFACE.md` — EQActionResolutionPolicy surface updated (+wait_close).
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/transaction/test_eq_wait_commit_boundary.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| player immediate actions are rollbackable before wait | an immediate action drafted on the transaction is on the working copy only (live size 0, is_live_unchanged); rollback discards it, live still untouched |
| wait commits draft and schedules ready reservation | `wait_close(...tx)` → tx committed; live holds both the committed immediate action (`strike`) and a scheduled ready `turn` |

Plus: after commit, `draft_push`/`draft_cancel` are no-ops (boundary closed); `wait_close` without a transaction schedules only the ready turn (policy-only path, backward-compatible).

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=31 checks=402 failures=0; [api-surface] ok
```

## Design notes (no shrink)

- **wait = commit + schedule-ready** composed from existing contracts (`EQTransaction.commit` + `EQActionResolutionPolicy.on_turn_finished`), not a new bespoke path. The transaction stays scheduler-generic; the AR policy owns the "what wait means" semantics.
- **Commit boundary guard**: drafting after commit is a no-op, so the wait commit is a clean point of no return for the turn.
- Full rollback (not per-action undo) satisfies "rollbackable before wait"; finer undo is a possible future refinement, not needed for the acceptance.

## UX path reduction

- Added: `EQActionResolutionPolicy.wait_close`. Narrowed: immediate actions go through the transaction draft (rollbackable); commit closes drafting. Residual: none.

## Deviations

- None beyond the planned wait_close addition + the transaction guard.

## Repair-now / follow-up

None. Next: EQM-072 (deterministic random + replay proof) — `EQRng` (seeded, serializable) such that snapshot restore reproduces random-dependent order/results under the same seed. This is a standard-semantics, fixed-target task → delegating to Codex 5.5 with a pinned contract (I make the snapshot-integration decision; the orchestrator owns the gate + surface).
