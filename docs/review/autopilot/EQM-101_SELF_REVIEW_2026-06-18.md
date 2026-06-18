# EQM-101 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — demo design + golden baselines). Repair: 0.

## Execution summary

Completed the multi-genre demo suite. CTB, wait-turn, and action-resolution demos
already existed; this task adds **energy, phase, and stack** demos, a golden for the
action-resolution demo, and the policy-selection manual. Each demo runs headless and
is approval-tested against a golden trace; phase and stack are compositions on the
existing total order (no new policy), demonstrating the "compose before adding a
policy" principle.

## Changed files

- `demos/energy_battle/energy_battle.gd`, `demos/phase_battle/phase_battle.gd`, `demos/stack_resolution/stack_resolution.gd` (new).
- `test_project/tests/debug_scene/test_energy_battle_demo.gd`, `test_phase_battle_demo.gd`, `test_stack_resolution_demo.gd`, `test_demo_battle_golden.gd` (new).
- `test_project/tests/golden/demo_energy_battle.trace.jsonl`, `demo_phase_battle.trace.jsonl`, `demo_stack_resolution.trace.jsonl`, `demo_action_resolution.trace.jsonl` (new — baselined via `./tools/test.sh --update-golden <case>`).
- `docs/manual/policy_selection.md` (new).

## Acceptance result — met

| acceptance | result |
|---|---|
| CTB, energy, wait-turn, action-resolution, phase, stack demos load | all six present under `demos/`; CTB/wait-turn pre-existing, energy/phase/stack/action-resolution added/golden'd; none environment-blocked (all buildable on the public API) |
| each demo emits its golden trace headless | six `demo_*.trace.jsonl` goldens under `test_project/tests/golden/`; each `test_*_demo.gd` compares exactly and re-baselines only via `--update-golden <case>` |
| per DETERMINISM_TRACE_TEST_POLICY | goldens created via the explicit `--update-golden` flow (never a normal run); sanity assertions independent of the golden anchor correctness |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=46 checks=640 failures=0
goldens baselined: demo_energy_battle, demo_phase_battle, demo_stack_resolution, demo_action_resolution (--update-golden)
```

Sanity anchors (independent of the byte golden): energy → fastest accruer (rogue) acts
first; phase → ally initiative band fully precedes enemy band in round 1; stack → LIFO
(`counter_negate, response_redirect, spell_fireball`); action-resolution → `reaction_fired`
+ `presentation_flush` present.

## Design notes (no shrink, no false blocking)

- **Nothing was environment-blocked.** The acceptance allows "environment-blocked
  with proof," but every genre is genuinely buildable on the public API, so all six
  ship as real, running, golden-tested demos. Claiming a block to avoid work would
  have been dishonest — phase and stack are real.
- **Phase and stack are compositions, not stubs.** Phase uses initiative bands on
  `EQFixedRoundPolicy` (allies 100+, enemies 20+ → ally phase precedes enemy phase),
  asserted structurally. Stack uses `priority = depth` on the L0 `EQRuntime` so the
  comparator pops last-pushed first (true LIFO), asserted by the resolution order.
  Both demonstrate the roadmap principle: try composition before a new policy class.
- **Goldens via the blessed flow.** Each golden was written only under
  `GODOT_UPDATE_GOLDEN==<case>` (the `--update-golden` path), never a normal run, per
  DETERMINISM_TRACE_TEST_POLICY §2/§5. The sanity assertions (not the golden) are the
  correctness check; the golden guards stability.
- **Energy demo distinct from CTB.** Same speeds, but `EQEnergyPolicy`'s carried
  (post-spend) energy model produces a different schedule than CTB's charge model —
  the two goldens differ, so the demo is not a CTB clone.

## UX path reduction

- Added: 3 demos + 1 golden + the genre map. Narrowed: the manual routes a user to
  exactly one demo to copy per genre; phase/stack avoid new API. Residual: a "phase"
  and "stack" *policy* could be added later if composition proves too fiddly for
  users — deferred deliberately (no evidence it is needed).

## Deviations

- Added a golden for the existing `demo_battle` (action-resolution suite member) so
  every suite genre has a byte golden; `test_action_resolution_demo.gd` keeps the
  determinism/API-usage checks, `test_demo_battle_golden.gd` adds the golden.

## Repair-now / follow-up

None. Next: EQM-102 (binary heap backend + trigger indexing — performance). Numeric
budgets declared before benchmarking; backend selectable without API break. Clear,
contract-pinnable → **Codex 5.5 candidate** (orchestrator pins budgets + owns the gate).
