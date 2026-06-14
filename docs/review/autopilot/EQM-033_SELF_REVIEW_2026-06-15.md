# EQM-033 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Added `EQPrediction`, a pure hypothetical API. `branch(runtime)` clones the live scheduler (snapshot→restore) and re-registers active actors with copied data; `predict_turns(runtime, n)` advances the branch one step at a time (pop → policy reschedule), returning the next-N actor order without touching live state. Added `EQSnapshot.equals` to assert purity.

## Changed files

- `addons/event_queue_manager/runtime/eq_prediction.gd` — `EQPrediction.branch` / `predict_turns`.
- `addons/event_queue_manager/runtime/eq_snapshot.gd` — `EQSnapshot.equals(a, b)` (deep snapshot compare).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQPrediction: L0`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/core/test_eq_prediction.gd` — purity, predict==actual, branch independence, act-now-vs-wait, empty/no-policy.

## Acceptance result — met

| acceptance | result |
|---|---|
| prediction returns expected order | `predict_turns(rt,5)` on a CTB runtime → faster actor first; equals the actual resolved order |
| live queue unchanged (purity) | `EQSnapshot.equals(snapshot_before, snapshot_after)` true across a predict |
| deterministic seed state preserved | live current_tick/counters/entries unchanged; same live state → same prediction |
| hypothetical-branch API (branch → virtual advance → discard) | `branch()`: mutating branch actor data / advancing it leaves live intact; two branches compare heavy vs light first action (act-now vs wait) → different futures, live untouched |
| watched-set re-evaluated per step, independent of N | `predict_turns` loops one step at a time (pop+reschedule), not a precomputed N-batch (structural; event-line watched-set lands Phase 4/5) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=16 checks=230 failures=0; [api-surface] ok
```

## API surface change (explicit golden re-baseline)

`--update`. Diff: new L0 class `EQPrediction` (branch, predict_turns); `EQSnapshot` gains `equals`. No L3 leak.

## Design notes

- **Branch isolation** = scheduler snapshot/restore + per-actor `data.duplicate(true)`, so neither the queue nor actor state leaks back to live. The branch is silenced (`emit_engine_diagnostics=false`) — a hypothetical must not log.
- **act-now vs wait** falls out of two branches with different first actions (heavy cedes the next turn to the opponent; light keeps initiative), demonstrating principle 17 without any live mutation.

## UX path reduction

- Added: `EQPrediction` (L0, pure). Narrowed: prediction operates only on a branch (never pops live). Residual: none.

## Deviations

- None beyond the planned surface additions.

## No sample-only completion

Purity/match/independence asserted directly; no sample (the CTB sample battle is the next task, EQM-034).

## Repair-now / follow-up

None. Next: EQM-034 (minimal CTB sample battle + quickstart) — the first learning-path sample, with a headless golden trace; then EQM-035 closes the v0.1 MVP milestone with the evaluation.
