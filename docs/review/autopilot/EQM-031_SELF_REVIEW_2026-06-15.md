# EQM-031 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Implemented `EQCTBPolicy` on the EQM-030 policy contract. CT is mapped to an integer delay (`ceil(cost*scale/speed)`, no float in ordering keys): faster actors get shorter delays and thus more turns, heavy actions delay the next turn, waits shorten it, and haste/slow are expressed as changes to the actor's `data[speed]` read fresh on each reschedule.

## Changed files

- `addons/event_queue_manager/resources/policies/eq_ctb_policy.gd` — `EQCTBPolicy` (speed_key/base_cost/scale, delay_of, seed, on_turn_finished).
- `tools/check_api_surface.py` — `EQCTBPolicy: L1`.
- `docs/design/API_SURFACE.md` — L1 table updated.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/policy/test_eq_ctb_policy.gd` — faster-more-turns, cost delay, haste/slow, int/monotonic/deterministic.

## Acceptance result — met

| acceptance | result |
|---|---|
| faster actor extra turns | speed 20 vs 10 over 9 advances → fast > slow and ≈2× |
| heavy action delay | cost 200 → delay > normal (cost 100) |
| wait action shorter delay | cost 50 → delay < normal |
| haste/slow next-turn | speed 20 → sooner; speed 5 → later (vs speed 10) |

Plus: delay is `int` ≥ 1 and deterministic for equal speed+cost.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=14 checks=206 failures=0; [api-surface] ok
```

## API surface change (explicit golden re-baseline)

`python3 tools/check_api_surface.py --update`. Diff: new L1 class `EQCTBPolicy` (speed_key, base_cost, scale, delay_of, seed, on_turn_finished). No L3 leak; intended addition only.

## Design notes

- **Integer CT** keeps float out of the ordering (§12); `scale` gives speed resolution and the ceil division (`(c*scale + sp-1)/sp`) guarantees forward progress (delay ≥ 1).
- **haste/slow = speed datum** (read each reschedule) rather than a bespoke modifier — per-entity state is acceptance-defined (Q16), and it falls out of the policy reading `data[speed]` every turn.
- Independent policy (not yet reduced to the event-line model); the reducibility proof is EQM-053.

## UX path reduction

- Added: `EQCTBPolicy` (L1). Narrowed: speed from `data` (no built-in field); `cost <= 0 → base_cost` is an explicit default, not a silent fallback chain. Residual: none.

## Deviations

- None beyond the planned surface addition.

## No sample-only completion

Direct delay/frequency/monotonicity assertions via a driven runtime; no sample (the CTB sample battle is EQM-034).

## Repair-now / follow-up

None. Next: EQM-032 (EQManager Node) — wires a policy into a scene-local node with the six signals and the game-loop driver contract, giving the ergonomic L0 flow (register → turn_ready → finish) without manual policy calls.
