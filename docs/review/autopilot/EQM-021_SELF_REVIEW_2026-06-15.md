# EQM-021 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Added the actor/action public API. `EQActorState` holds a serializable identity (`actor_id`) + acceptance-defined `data` + a transient weak binding (never serialized). `EQActionResult` is the typed finish-action result with cost/delay validation. `EQActorRegistry` owns id registration with duplicate, empty, and reuse rejection (actor_id reuse forbidden per semantics §13), backing the `tie_break = &"actor_id"` totality from EQM-020. Five append-only error codes were added.

## Changed files

- `addons/event_queue_manager/runtime/eq_error.gd` — +5 codes (actor.duplicate_id/id_reused/empty_id, action.negative_delay/negative_cost).
- `addons/event_queue_manager/runtime/eq_actor_state.gd` — `EQActorState`: actor_id + data + weak `bind/bound/is_bound`; `to_dict/from_dict` carry identity+data only.
- `addons/event_queue_manager/runtime/eq_action_result.gd` — `EQActionResult`: cost/delay/allow_negative_cost + `validate()`.
- `addons/event_queue_manager/runtime/eq_actor_registry.gd` — `EQActorRegistry`: register/validate_register/is_registered/get_state/unregister/actor_ids/size; `_active`/`_retired`.
- `docs/design/ERROR_CONTRACT.md` — +5 code rows.
- `test_project/tests/resource/test_eq_actor_registry.gd`, `test_eq_action_result.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| actor id registration | `register` returns an `EQActorState`; is_registered/get_state/size verified |
| duplicate rejection | duplicate → null + `ACTOR_DUPLICATE_ID`, size unchanged |
| weak binding placeholder | `bind/bound/is_bound`; freed Object → not bound; `to_dict` omits the binding |
| action cost/delay result validation | negative delay → `ACTION_NEGATIVE_DELAY` (always); negative cost → `ACTION_NEGATIVE_COST` unless `allow_negative_cost` (§12); valid result clean |

Extra (semantics §13): actor_id reuse forbidden — unregister retires the id; re-register → null + `ACTOR_ID_REUSED`.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=11 checks=167 failures=0
```

## UX path reduction (self-review checklist)

- **Added**: `register_actor`-style `register(actor_id)` (single accepted key = StringName id); `EQActionResult` typed result.
- **Narrowed**: registration rejects empty/duplicate/reused ids; `finish_action` will take `EQActionResult`, not a raw Dictionary (enforced when EQM-022 wires it).
- **Residual fallback**: none. No silent overwrite or id reuse path.

## Deviations

- None beyond the listed targets (the +5 codes were planned).

## No sample-only completion

Direct registration/validation/weak-binding assertions; no sample.

## Repair-now / follow-up

None. Per-entity progression (WT/CT/AP) is intentionally NOT a built-in field — it lives in `EQActorState.data` per Q16. Real rebind-on-load of the weak binding is EQM-085. Next: EQM-022 (headless facade) unblocked — it coordinates scheduler + policy + registry + finish_action and exposes the dev/shipped resilience mode toggle that acts on the recoverability classes recorded since EQM-020.
