# EQM-030 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Established the L1 policy contract (`seed` / `on_turn_finished`, expressed purely through runtime L0 primitives) and implemented `EQFixedRoundPolicy`. Fixed round maps onto the core with no new ordering machinery: round N = `due_tick=N`, turn `priority = initiative`, so EQOrdering yields initiative-DESC then registration-order ties; each actor re-enters via `current_tick + 1`.

## Changed files

- `addons/event_queue_manager/resources/policies/eq_policy.gd` — +`seed`/`on_turn_finished` no-op contract (untyped runtime/result to avoid a class-name cycle).
- `addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd` — `EQFixedRoundPolicy` (initiative_key, seed, on_turn_finished).
- `tools/check_api_surface.py` — `EQFixedRoundPolicy: L1` in LAYER_MAP.
- `docs/design/API_SURFACE.md` — L1 table updated.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/policy/test_eq_fixed_round_policy.gd` — battle-start, refresh, tie-break, removal skip.

## Acceptance result — met

| acceptance | result |
|---|---|
| battle-start ordering | `[fast, mid, slow]` from initiative {9,5,1} (priority DESC) |
| round refresh | round 2 identical to round 1 (`[fast,mid,slow,fast,mid,slow]`) |
| equal initiative tie-break | three actors at initiative 5 resolve in registration order `[a,b,c]` |
| actor removal skip | `b` unregistered mid-round → no further turns; pending turn `invalid_event_skipped` in trace; `a`/`c` keep acting |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=13 checks=197 failures=0; [api-surface] ok
```

Gate (§4 policy + API surface): ordering contract green; surface gate green after explicit golden re-baseline.

## API surface change (explicit golden re-baseline)

`python3 tools/check_api_surface.py --update`. Diff: `EQPolicy` gains `seed` + `on_turn_finished`; new L1 class `EQFixedRoundPolicy` (initiative_key, seed, on_turn_finished). No L3 leak; intended additions only (+32/-1 lines in the golden).

## Design notes

- **Policy = ordering rule over L0 primitives**, never touching the scheduler backend. The same two hooks carry CTB/Energy/Wait/AP — verified-by-design here, exercised next in EQM-031.
- **Runtime auto-delegation deferred to EQM-032.** This task leaves `EQRuntime` untouched (EQM-022 mode/flow intact); the test drives `seed` + `on_turn_finished` explicitly. EQManager will wire finish→policy so the L0 flow (register → turn_ready → finish) needs no manual policy calls.

## UX path reduction

- Added: `EQFixedRoundPolicy` (L1 Resource swap). Narrowed: initiative read from `data` (no built-in field). Residual fallback: none (removed actors are skipped, not silently rescheduled).

## Deviations

- None beyond the planned surface additions.

## No sample-only completion

Direct policy-order assertions via a driven runtime; no sample. (The CTB sample battle is EQM-034.)

## Repair-now / follow-up

None. Next: EQM-031 (CTB policy) — same contract, CT-fills-by-speed scheduling; then EQM-032 wires the policy into EQManager's signal flow.
