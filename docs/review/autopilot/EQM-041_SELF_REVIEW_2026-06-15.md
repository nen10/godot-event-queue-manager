# EQM-041 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0. Terminal Phase 4 task — its completion is the Phase 4 milestone.

## Execution summary

Implemented `EQWaitTurnPolicy` (Tactics Ogre / FFT) on the EQM-030 contract and added a learning-path wait-turn demo with a golden trace. A unit's turn is scheduled at `due_tick = wait`, so the scheduler pops the smallest-wait unit and the clock jumps straight to it (instant resolve, no idle ticks). The action's cost sets the next wait; equal wait is broken by agility (higher first) then registration order.

## Changed files

- `addons/event_queue_manager/resources/policies/eq_wait_turn_policy.gd` — `EQWaitTurnPolicy` (wait_key/agility_key/base_cost; seed/on_turn_finished).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQWaitTurnPolicy: L1`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `demos/wait_turn_tactics/{wait_turn.gd,wait_turn.tscn,README.md}` — learning-path demo.
- `tests/golden/demo_wait_turn.trace.jsonl` — demo golden (`--update-golden demo_wait_turn`).
- `test_project/tests/policy/test_eq_wait_turn_policy.gd`, `test_project/tests/debug_scene/test_wait_turn_demo.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| units with wait values resolve instantly to next ready unit | waits 3/5/8 → resolve order b,a,c; current_tick jumps 3→5→8 (no idle stepping) |
| action cost modifies next wait | heavy (cost 10) → next wait 10; lighter (cost 3) → shorter next wait |
| equal wait tie-break explained | equal wait → higher agility first; equal agility → registration order; documented in policy doc + POLICY.md and asserted in tests |

Demo golden (DETERMINISM §5): archer(wait 4)→tick 4, knight(6)→6, golem(9)→9, then archer→104 (normal next wait 100); smallest-wait unit leads.

## Test summary

```text
./tools/test.sh --update-golden demo_wait_turn -> golden written, PASS
./tools/test.sh -> RESULT: PASS (exit 0); files=20 checks=256 failures=0; [api-surface] ok
```

## API surface change (explicit golden re-baseline)

`--update`. Diff: new L1 class `EQWaitTurnPolicy`. No L3 leak. (Demo has no class_name → not in the surface.)

## Design notes

- **Instant resolve falls out of `due_tick = wait`** + the scheduler's min-due-tick pop and clock jump — no special "skip idle ticks" code, just the core ordering.
- **Equal-wait tie-break = agility (priority) then sequence** — the Q09 "lower base WT first" rule expressed via an explicit agility stat, keeping a deterministic total order.

## UX path reduction

- Added: `EQWaitTurnPolicy` (L1) + wait-turn demo. Narrowed: wait/agility from `data` (no built-in field); `cost <= 0 → base_cost`; demo is public-API-only and explicitly learning-path. Residual: none.

## No sample-only completion

Policy behaviour is asserted directly (instant resolve / cost / tie-break); the demo is isolated as a learning path with its own golden, not used to claim any other feature complete.

## Deviations

- None beyond the planned surface addition + demo golden.

## Repair-now / follow-up

None. **Phase 4 (energy + wait-turn) milestone reached** — both genres covered by independent policies on the shared contract. Next frontier is Phase 5 (EQM-050 reservation schema), the first L2 surface and the start of the deep reservation/event-line path. Pausing at the milestone for user direction.
