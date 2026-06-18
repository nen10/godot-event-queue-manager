# EQM-084 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — full-API dogfood). Repair: 1 (the dogfood itself hit a real API friction — F1 — which I worked around in-slice and recorded; no addon code changed).

## Execution summary

Built `dogfood/action_resolution/battle.gd`, a playable Action Resolution slice using the public API only, exercising AP turns + a counter reaction + effect/presentation records + deterministic RNG end to end, with a golden trace and a friction report.

## Changed files

- `dogfood/action_resolution/battle.gd`, `README.md` (new); `test_project/dogfood` → `../dogfood` (symlink, tracked).
- `tests/golden/dogfood_action_resolution.trace.jsonl` (golden, via `--update-golden`).
- `docs/review/DOGFOOD_FRICTION_2026-06-18.md` (friction report).
- `test_project/tests/debug_scene/test_dogfood_action_resolution.gd` (headless golden + subsystem-coverage checks).

## Acceptance result — met

| acceptance | result |
|---|---|
| uses public API only (no runtime internals) | `battle.gd` imports only public classes (Manager/Policy/Reservation/Trigger/Condition/EffectRecord/Chunk/PresentationBuffer/Rng/Trace); no `runtime`-internal access |
| ships its own golden trace | `dogfood_action_resolution.trace.jsonl`; deterministic (seeded RNG); coverage: turn ×8, effect ×8, reaction_fired ×2 |
| friction report records ergonomics findings | `DOGFOOD_FRICTION_2026-06-18.md`: 4 findings, each classified |
| findings become queue candidates or explicit no-change | F1 → EQM-100 doc (+optional polish); F2 → EQM-085 signals + EQM-100 doc; F3/F4 → no-change with rationale; 0 blocking, 0 new tasks forced |

## Test summary

```text
./tools/test.sh --update-golden dogfood_action_resolution -> golden written, PASS
./tools/test.sh -> RESULT: PASS (exit 0); files=38 checks=510 failures=0; [api-surface] ok
```

api-surface unchanged (battle.gd has no class_name → not in the surface).

## The friction (F1) — a genuine dogfood catch

While wiring the slice, `policy.wait_close(runtime, …)` deadlocked the manager loop after one turn: `EQManager.step()` suspends on `turn_ready` and only `finish_action` clears it, but `wait_close` drives the runtime directly. Fixed in-slice by using `manager.finish_action` (the manager-driven path); recorded as F1 (doc + optional API polish). This is exactly the value of dogfooding — the two turn-close paths compose poorly, and only a real consumer surfaces it. No addon code was changed (the boundary is correct; the fix is documentation/ergonomics).

## Phase 8 boundary observation — resolved

The Phase-8 review noted the effect/presentation records were not yet produced by a real consumer. This slice produces them (effect records into a chunk, visuals into a presentation buffer) — confirming the records are usable in a real flow (F2 records the manual-wiring ergonomics).

## No sample-only completion

The slice's acceptance is a golden trace + subsystem-coverage assertions + the friction report; it is the dogfood, explicitly a consumer slice, not used to claim any other feature complete.

## Deviations

- Added a `test_project/dogfood` symlink (mirrors the demos symlink) so the slice is reachable headless.

## Repair-now / follow-up

None blocking. Candidates recorded in the friction report attach to EQM-100 (manual) and EQM-085 (node bridge signals). Next: EQM-085 (Godot node bridge — save/load rebind, actor-deletion handling, multi-domain signal bridge), which is also where the F2 effect/presentation signal-wiring follow-up naturally lands. Orchestrator-direct.
