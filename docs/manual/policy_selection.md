# Choosing a policy (genre map)

A policy answers "whose turn is next?" (L1). Pick by how your game advances turns.
Every row below has a runnable, golden-tested demo under `demos/` — copy the closest
one. All demos use the public API only and create their own `EQConfig` (no bundled
default).

| genre / feel | policy | demo | how it orders |
|---|---|---|---|
| Classic initiative / **team phases** | `EQFixedRoundPolicy` | `demos/phase_battle/` | one round at a time, ordered by an `initiative` key (priority DESC). Initiative *bands* give phases (all allies then all enemies). |
| **Charge Time / ATB** | `EQCTBPolicy` | `demos/ctb_battle/` | each actor charges by `speed`; acts when its charge crosses a cost. Faster = more turns. |
| **Energy threshold** | `EQEnergyPolicy` | `demos/energy_battle/` | accrue energy by `speed` each tick; act at `threshold`; carried (post-spend) energy is user-inspectable. |
| **Wait-based** (wait-turn) | `EQWaitTurnPolicy` | `demos/wait_turn_tactics/` | a per-actor wait counter; lower wait acts first, equal-wait broken by `agility`. |
| **Action economy / SRPG** (AP, reactions) | `EQActionResolutionPolicy` | `demos/action_resolution/` | AP recovers per tick; a turn is ready at `ap_max`; pairs with reservations/triggers for prepared + counter actions. |
| **Stack / LIFO** (trading-card-style responses) | *(composition, no policy)* | `demos/stack_resolution/` | items share a tick with `priority = stack depth`; the total order (priority DESC) pops the last-pushed first. |

## Notes

- **Phase and stack need no dedicated policy.** They are *compositions* on the
  existing total order (`due_tick ASC, priority DESC, sequence ASC`): phases are
  initiative bands on `EQFixedRoundPolicy`; a stack is `priority = depth` on the L0
  `EQRuntime`. This is deliberate — new genres should try composition before a new
  policy class (ROADMAP §3.1, keep L0/L1 small).
- **Determinism is uniform.** Every policy resolves through the same comparator and
  emits the same canonical trace kind (`resolved`, with the `decided_by` tie-break),
  so each demo is approval-tested against a golden
  (`test_project/tests/golden/demo_*.trace.jsonl`,
  `DETERMINISM_TRACE_TEST_POLICY §5`). Re-baseline only via
  `./tools/test.sh --update-golden <case>`.
- **A policy is a Resource.** Assign a concrete subclass to `EQConfig.policy`; a null
  or base `EQPolicy` instance is a validation error, never a silent default
  (see `concepts.md` and `EDITOR_UI_CONTRACT.md` config panel).

## Which demo do I copy?

- "I just want speed-based turns" → `ctb_battle` (or `energy_battle` if you want a
  visible energy bar value).
- "Allies move, then enemies" → `phase_battle`.
- "Tactics with wait/defer" → `wait_turn_tactics`.
- "AP, prepared attacks, counters" → `action_resolution` (then read
  `reservations.md` + `action_resolution.md`).
- "Spells with responses that resolve first" → `stack_resolution`.
