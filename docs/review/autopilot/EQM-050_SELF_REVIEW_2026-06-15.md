# EQM-050 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct, design-critical L2 — kept in-house per the Phase-5 design-shrink caution). Repair: 0.

## Execution summary

Established the first L2 (reservation) surface: `EQActionDefinition` (authored schema) and `EQReservation` (runtime instance), with per-kind validation and serialization. Six reservation kinds (immediate / prepared / reaction-preparation / wait / ready / operation) and the fields tags/duration/rumination are validated; `duration = -1` is the unlimited (∞) sentinel so a reaction preparation can close by reaction count alone (Q06). Eight append-only reservation error codes were added.

## Changed files

- `addons/event_queue_manager/runtime/eq_error.gd` — +8 reservation codes.
- `addons/event_queue_manager/resources/eq_action_definition.gd` — `EQActionDefinition` (L2): Kind enum, delay/tags/duration/rumination/operation_target_tag, `DURATION_UNLIMITED`, validate, to_dict/from_dict.
- `addons/event_queue_manager/runtime/eq_reservation.gd` — `EQReservation` (L2): actor_id/definition/event_id/status/counters, validate (delegates to definition), to_dict/from_dict (definition inlined, no live ref).
- `docs/design/ERROR_CONTRACT.md` — +8 code rows.
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — L2 column populated.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/resource/test_eq_action_definition.gd`, `test_eq_reservation.gd`.

## Acceptance result — met

| acceptance (fields validate) | result |
|---|---|
| immediate | valid at delay 0; delay>0 → `immediate_nonzero_delay` |
| prepared | valid at delay>0; delay 0 → `prepared_zero_delay` |
| reaction preparation | valid with duration>0 or -1 (∞); duration 0 → `reaction_needs_duration` |
| wait / ready | valid (turn-flow kinds) |
| operation action | valid with `operation_target_tag`; empty → `operation_needs_target` |
| tags | typed `Array[StringName]`, survive `.tres` roundtrip |
| duration | -1 = unlimited valid; < -1 → `invalid_duration` |
| rumination | >= 0; negative → `negative_rumination` |

Plus: `EQReservation` initialises counters from the definition, delegates validation (surfacing the definition's codes), serializes without a live reference, and a null definition → `missing_definition`.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=22 checks=291 failures=0; [api-surface] ok
```

L2 surface now populated (EQActionDefinition, EQReservation); api-surface gate green with no L3 leak into L0/L1.

## API surface change (explicit golden re-baseline)

`--update`. Diff: L2 column gains EQActionDefinition + EQReservation (first L2 classes). No L3 leak; layers now core 10 / L0 6 / L1 6 / L2 2.

## Design notes (no shrink)

- **Kinds are an enum, not strings** — invalid kinds are unrepresentable, and per-kind constraints are explicit codes (make-invalid-states-unrepresentable).
- **`duration = -1 = ∞`** keeps the Q06 "reaction prep closes by count, deadline ∞" expressible without a separate boolean.
- **Reservation runtime is serializable by value** (definition inlined), honoring the Adapter rule (no live Node in the save form), so EQM-051's pipeline state will snapshot cleanly.
- Conditions (solve/invalidation objects) and the resolution pipeline are deliberately deferred to EQM-060 / EQM-051 — this task is the schema, and over-reaching into them now would entangle two completion boundaries.

## UX path reduction

- Added: `EQActionDefinition`/`EQReservation` (L2, opt-in). Narrowed: enum kind (no string), per-kind validation; L0/L1 surface unchanged. Residual: none.

## Deviations

- One extra code beyond the planned 7 (`missing_definition`) — added when implementing EQReservation.validate so a null definition reports a precise code instead of an unrelated one. Recorded.

## Repair-now / follow-up

None. Next: EQM-051 (reservation scheduling/resolution pipeline) — immediate resolves at delay 0, prepared after delay, wait schedules a ready reservation, operation causes a target reservation. This is the integrated L2 runtime; kept orchestrator-direct (design-weighty).
