# EQM-072 Self-Review 2026-06-15

Pattern: **P2 delegation** — Codex 5.5 (gpt-5.5 xhigh) implemented an orchestrator-pinned contract; orchestrator owned the contract, the surface wiring, and the gate. Repair: 0 (accepted as authored; orchestrator expanded the class doc only). Terminal Phase 7 task — its completion is the Phase 7 milestone.

## Delegation record

- Contract: `EQM-072_deterministic_replay/IMPLEMENTATION_PLAN.md` — EQRng API (seed/state serialization via Godot RandomNumberGenerator), the replay-proof structure, and conventions were **fully pinned** (no design left open). Scope: eq_rng.gd + the test only; do not touch eq_snapshot/tools/golden.
- Executor: `codex exec -s workspace-write` (gpt-5.5). Stayed in scope: only `eq_rng.gd` + `test_eq_rng_replay.gd`; correctly anticipated the expected api-surface failure for the new class and reported the Godot suite green.

## Orchestrator review + merge

- Verified EQRng matches the contract: `to_dict` captures (seed, state); `from_dict` sets seed first, then state (the order that restores the exact stream position); randi/randi_range/randf/from_saved present. No extra API.
- Verified the replay-order test is a genuine proof, not a tautology: the scenario draws each event's due_tick and priority from the rng, so the resolved order depends on the rng stream; the run is done twice (uninterrupted vs with a midway `scheduler.snapshot()` + `rng.to_dict()` → restore into fresh instances), and the full resolved orders must be equal. A faulty state restore would diverge after the boundary.
- Polish: expanded the EQRng class doc to house style (seed/state, restore order). Wired the surface: `EQRng: core` in LAYER_MAP + API_SURFACE.md; re-baselined the golden.

## Changed files

- `addons/event_queue_manager/runtime/eq_rng.gd` (new; Codex + orchestrator doc).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` + `tests/golden/api_surface.json` (orchestrator surface wiring).
- `test_project/tests/transaction/test_eq_rng_replay.gd` (new; Codex).

## Acceptance result — met

| acceptance | result |
|---|---|
| snapshot restore reproduces random-dependent order and results under same seed | the random-scheduler scenario's full resolved order is identical with and without a midway snapshot+rng-state restore; same-seed determinism and save/restore stream continuation also asserted |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=32 checks=407 failures=0; [api-surface] ok
```

EQRng added to the `core` layer; no L3 leak.

## Design notes

- **EQRng self-serializes** (seed+state); the replay proof composes it with the existing EQScheduler snapshot — so `eq_snapshot.gd` did not need modifying (the listed target was satisfiable without a core schema change, as anticipated in the contract).
- A full game save bundles the scheduler snapshot and the rng dict; both restore independently and deterministically.

## UX path reduction

- Added: `EQRng` (core, deterministic). Narrowed: randomness flows through a seeded/serializable wrapper (no ad-hoc `randi()` that can't be snapshotted). Residual: none.

## Deviations

- `eq_snapshot.gd` listed as a target but not modified (EQRng self-serializes + existing scheduler snapshot suffices) — recorded, consistent with EQM-070.
- Class doc expanded by the orchestrator post-delivery (house style); surface wired by the orchestrator per the contract.

## Repair-now / follow-up

None. **Phase 7 (Transaction and rollback) milestone reached** — draft transaction (EQM-070), wait/commit boundary (EQM-071), and deterministic RNG + replay (EQM-072) complete. Next frontier is Phase 8 (EQM-080 effect/presentation records — the simulation/presentation split).
