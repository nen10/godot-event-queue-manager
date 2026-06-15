# Wait-Turn Tactics (learning-path sample)

A minimal Tactics Ogre / FFT-style wait-turn battle built with the **public**
Event Queue Manager API only. **Learning path**, not production, not a default —
a real game creates its own `EQConfig`. See `docs/manual/quickstart.md`.

- `wait_turn.gd` — `build()` / `run_trace(turns)` (used headless by the tests) and a `_ready()` that prints a few turns when the scene is played.
- `wait_turn.tscn` — the playable scene.

Units (wait, agility): archer (4, 7), knight (6, 4), golem (9, 2). The unit with
the smallest wait acts first; equal wait is broken by higher agility, then
registration order. The "it works" is proven by a golden trace
(`test_project/tests/golden/demo_wait_turn.trace.jsonl`).
