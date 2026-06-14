# CTB Battle (learning-path sample)

A minimal Charge Time Battle built with the **public** Event Queue Manager API
only. This is a **learning path**, not production and not a hidden default — a
real game creates its own `EQConfig`. See `docs/manual/quickstart.md`.

- `ctb_battle.gd` — `build()` / `run_trace(turns)` (used headless by the tests) and a `_ready()` that prints a few turns when the scene is played.
- `ctb_battle.tscn` — the playable scene (a single `Node` running the script).

The battle's "it works" is proven by a golden trace
(`test_project/tests/golden/demo_ctb_battle.trace.jsonl`), not by eyeballing —
see `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md` §5.

Combatants (speeds): rogue 22, hero 15, golem 8 — the faster combatant acts more often.
