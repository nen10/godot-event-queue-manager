# EQM-061 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct — trigger firing semantics are the design core). Repair: 0.

## Execution summary

Implemented `EQTriggerEngine`, the reaction-preparation runtime. Armed REACTION_PREPARATION reservations (paired with an EQCondition) fire at the sweep point after a matching event resolves; duration expiry removes a reaction before it can fire; owner/source are distinguished through the condition. Firing is one-shot (rumination + cycle guard are EQM-062).

## Changed files

- `addons/event_queue_manager/runtime/eq_trigger_engine.gd` — `EQTriggerEngine` (L2): arm / on_event_resolved (expire-then-fire) / _expire / armed_count / armed_for.
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQTriggerEngine: L2`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/trigger/test_eq_trigger_engine.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| counterattack triggers on incoming `<損害>` reservation | a reaction armed with `{tags:[damage], target:owner}` fires on a damage view to its owner; fired reservation is RESOLVED |
| duration expiry prevents trigger | armed@0 duration 5; matching damage at tick 8 → no fire, reaction dropped (8−0 > 5) |
| owner/source matching tested | damage targeting another actor → no fire; the owner's own damage (source == owner) → no fire (custom predicate); a genuine enemy hit → fires |

Plus: one-shot (consumed after firing, no second fire); non-matching events leave it armed; firing only at the sweep point (`on_event_resolved`).

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=28 checks=358 failures=0; [api-surface] ok
```

## Design notes (no shrink)

- **expire-before-fire**: `_expire` runs first in `on_event_resolved`, so a reaction whose window has closed cannot fire even if the event matches — the determinism-relevant ordering.
- **owner/source via the condition**, not hardcoded: the engine holds `owner = reservation.actor_id` and delegates the enemy-vs-self distinction to EQCondition (match_target / custom predicate). This keeps the matching policy in the condition (EQM-060) and the engine generic.
- **sweep point only** (§6): reactions fire via `on_event_resolved`, never interleaved mid-resolution — the trigger collection window.
- **one-shot here**; the engine exposes the seam (armed list + arm/fire) that EQM-062 extends with rumination re-arming and the bounded-chain cycle guard.

## UX path reduction

- Added: `EQTriggerEngine` (L2). Narrowed: reactions fire only at the sweep point via condition matching; a null condition never fires (safe default). Residual: none.

## Deviations

- None beyond the planned surface addition.

## Repair-now / follow-up

None. Next: EQM-062 (rumination and cycle prevention) — rumination count decrements and reschedules; a max-chain guard stops infinite loops with an explicit error/event. Touches eq_reservation_runtime + eq_trigger_engine; kept orchestrator-direct (determinism/safety-sensitive).
