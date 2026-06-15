# EQM-051 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct, design-weighty L2). Repair: 0.

## Execution summary

Implemented `EQReservationRuntime`, the L2 scheduling/resolution pipeline over `EQRuntime`. `submit()` places a reservation per its kind; `resolve_next()` pops the next ready reservation, marks it resolved, and applies its effect. Added `target_id` to `EQReservation` for operation targeting.

## Changed files

- `addons/event_queue_manager/runtime/eq_reservation.gd` — `target_id` field + roundtrip.
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` — `EQReservationRuntime` (L2): submit / resolve_next / _cause_target_reservation / armed_for / pending.
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQReservationRuntime: L2`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/core/test_eq_reservation_runtime.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| immediate resolves at delay 0 | submit IMMEDIATE → scheduled at current tick (0); resolve_next → RESOLVED at tick 0 |
| prepared resolves after delay | submit PREPARED delay 5 → scheduled at tick 5; resolve_next advances the clock to 5 |
| wait schedules ready reservation | submit WAIT delay 3 → the wait resolves immediately and a single READY reservation is scheduled at tick 3 |
| operation causes target reservation | resolving an OPERATION (target_id=target, tag=counter) arms a reaction reservation on the target carrying the `counter` tag |

Plus: REACTION_PREPARATION is armed (no scheduler event), queryable via `armed_for`.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=23 checks=308 failures=0; [api-surface] ok
```

Resolution events flow through `EQRuntime.advance`, so reservations appear in the canonical trace (kind = "reservation").

## API surface change (explicit golden re-baseline)

`--update`. Diff: L2 gains `EQReservationRuntime`; `EQReservation` gains `target_id`. No L3 leak.

## Design notes (no shrink)

- **kind-dispatched submit** keeps the six reservation semantics in one place; `wait → ready` and `operation → target reservation` are the Action-Resolution couplings the model is built around, implemented directly rather than stubbed.
- **reaction preparation is armed, not scheduled** — the trigger that fires it is EQM-061; arming here (status + `_armed`) is the seam that EQM-061 plugs into, without pre-building the trigger engine.
- Conditions (EQM-060), trigger firing, and the rumination cycle guard (EQM-062) are deliberately out of scope — this task is the scheduling/resolution skeleton, and reaching into them would entangle completion boundaries.

## UX path reduction

- Added: `EQReservationRuntime` (L2) + `EQReservation.target_id`. Narrowed: reservations go through `submit` (kind-validated definitions), not raw scheduler calls. Residual: none.

## Deviations

- None beyond the planned `target_id` addition.

## Repair-now / follow-up

None. Next: EQM-052 (AP and ready-reservation model for Action Resolution Turn-Based) — the design core: a ready reservation grants the turn after an AP-recovery delay, AP spend/recovery is deterministic, and the turn closes through wait. Kept orchestrator-direct.
