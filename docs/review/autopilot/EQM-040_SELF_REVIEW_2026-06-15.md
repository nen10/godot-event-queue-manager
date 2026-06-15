# EQM-040 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 1 (test-only type annotation; no product change).

## Execution summary

Implemented `EQEnergyPolicy` on the EQM-030 contract. Energy accumulates by speed; on reaching the threshold the actor acts, spends the action's cost, and carries over the remainder, so a cheap action banks energy and the next turn comes sooner. Integer mapping (no float): delay = ceil((threshold - carry)/speed); the energy at the upcoming turn is stored so the next finish subtracts its cost.

## Changed files

- `addons/event_queue_manager/resources/policies/eq_energy_policy.gd` — `EQEnergyPolicy` (speed_key/energy_key/threshold/base_cost; _arm/seed/on_turn_finished; carry-over via `_eq_energy_at_turn`).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQEnergyPolicy: L1`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/policy/test_eq_energy_policy.gd` — readiness, cost, speed, carry-over.

## Acceptance result — met

| acceptance | result |
|---|---|
| threshold readiness | speed 10, threshold 100 → first turn at tick 10 (ceil(threshold/speed)) |
| action cost | cost 150 → longer refill than cost 100; cost 50 → shorter |
| speed differences | speed 20 vs 10 over 9 turns → faster takes more |
| wait | a wait (cheap action) refills faster than normal |
| energy carry-over | after a wait (cost 50) the actor shows `energy == 50` and refills in 5 ticks (carry 50 + speed 10) vs 10 fresh |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=18 checks=241 failures=0; [api-surface] ok
```

## Repair record (gate REJECT → fix, attempt 1/3)

- Symptom: parse error — `var wait_delay := <untyped rt>.scheduler...` could not infer (the `rt` came from an untyped `Array` element). Caught by the masked-failure guard.
- Fix: annotated `var wait_delay: int = …`. Test-only; no product change.

## API surface change (explicit golden re-baseline)

`--update`. Diff: new L1 class `EQEnergyPolicy`. No L3 leak.

## Design notes

- **Carry-over is the differentiator** from CTB: CTB recomputes delay from cost each turn; energy banks the remainder, so leftover energy compounds (two cheap actions in a row come faster still). Modeled by storing the at-turn energy and subtracting cost.
- Independent policy (delay-driven, not the event-line backend); reducibility is EQM-053.

## UX path reduction

- Added: `EQEnergyPolicy` (L1). Narrowed: speed/energy from `data` (no built-in field); `cost <= 0 → base_cost` explicit default. Residual: none.

## Deviations

- None beyond the planned surface addition.

## No sample-only completion

Direct readiness/cost/speed/carry-over assertions; no sample.

## Repair-now / follow-up

None. Next: EQM-041 (wait-turn policy, TO/FFT) — instant resolve to the next-ready unit, action cost modifies the next wait, equal-wait tie-break, plus a wait-turn demo with a golden trace.
