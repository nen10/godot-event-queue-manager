# EQM-062 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct — determinism/safety-sensitive cycle guard). Repair: 0. Terminal Phase 6 task — its completion is the Phase 6 milestone.

## Execution summary

Added rumination and the trigger cycle guard. A resolved reservation with ruminations left decrements and reschedules (EQReservationRuntime); a fired reaction re-arms while ruminations remain (EQTriggerEngine). `EQTriggerEngine.fire_cascade` drives a bounded trigger cascade — a runaway chain is truncated at `max_chain` and recorded as a `TRIGGER_CHAIN_LIMIT` fault (BUDGET_EXCEEDED), never an infinite loop or a crash.

## Changed files

- `addons/event_queue_manager/runtime/eq_error.gd` — +`eqm.trigger.chain_limit` (BUDGET_EXCEEDED).
- `addons/event_queue_manager/runtime/eq_trigger_engine.gd` — rumination re-arm in `on_event_resolved`; `max_chain` / `faults` / `fire_cascade`.
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` — rumination reschedule in `resolve_next`.
- `docs/design/ERROR_CONTRACT.md` — +chain_limit row.
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` + `tests/golden/api_surface.json` — EQTriggerEngine surface updated.
- `test_project/tests/trigger/test_eq_rumination_cycle_guard.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| rumination count decrements and reschedules | a PREPARED reservation with rumination 2 resolves 3 times (initial + 2 reschedules), count 2→0, then stops; a reaction with rumination 2 fires 3 times (re-armed twice) then is consumed |
| max chain guard stops infinite loops with explicit error/event | a runaway cascade (huge rumination + a follow-up re-emitting a matching event) is bounded at `max_chain`; a single `TRIGGER_CHAIN_LIMIT` fault (BUDGET_EXCEEDED) is recorded; no crash |

Plus: rumination 0 stays one-shot (EQM-061 compatibility preserved); a terminating cascade records no fault.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=29 checks=370 failures=0; [api-surface] ok
```

## Design notes (no shrink)

- **Two bounding mechanisms, distinct concerns**: rumination is *count-bounded* (it cannot loop forever on its own — decrement to 0); the cycle guard is for *trigger cascades* (a reaction causing an event that fires more reactions), bounded by `max_chain` (the SEMANTICS §8 engineering backstop / bounded round).
- **Fail-safe, not crash**: exceeding the chain limit records a structured fault (BUDGET_EXCEEDED) and truncates — consistent with RUNTIME_RESILIENCE (shipped never crashes; dev would surface it loudly via the runtime toggle). No silent swallow.
- **Backward-compatible**: rumination defaults to 0 → one-shot, so EQM-061's reaction tests are unchanged.
- Window-nest ↔ trigger-nest crossing budget (§8) remains a deferred narrow item; this task implements the trigger-chain bound + absolute max.

## UX path reduction

- Added: `EQTriggerEngine.fire_cascade` / `max_chain` / `faults`. Narrowed: cascades are always bounded (no unbounded-loop path); chain overflow is an explicit recorded fault. Residual: none.

## Deviations

- None beyond the planned +1 code and surface update.

## Repair-now / follow-up

None. **Phase 6 (Trigger / reaction engine) milestone reached** — condition/tag matching (EQM-060, Codex-delegated), reaction preparation runtime (EQM-061), and rumination + cycle guard (EQM-062) complete. Next frontier is Phase 7 (EQM-070 transaction snapshot — player-turn draft, rollback, commit).
