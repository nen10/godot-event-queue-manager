# Action Resolution dogfood slice

A minimal playable Action Resolution Turn-Based slice built with the **public**
Event Queue Manager API only — the addon's own dogfood. It wires, end to end:

- AP-recovery turns (`EQActionResolutionPolicy` via `EQManager`)
- a counter reaction (`EQTriggerEngine` + `EQCondition` on a reaction-preparation reservation, with rumination)
- simulation effects + queued visuals (`EQEffectRecord` / `EQEffectChunk` / `EQPresentationBuffer`)
- deterministic randomness (`EQRng`)
- one canonical trace (`EQTrace`), proven against a golden.

`battle.gd` uses only public classes (no `runtime` internals). Its behaviour is
verified headless by `test_project/tests/debug_scene/test_dogfood_action_resolution.gd`
against `tests/golden/dogfood_action_resolution.trace.jsonl`.

API ergonomics findings from building this slice: `docs/review/DOGFOOD_FRICTION_2026-06-18.md`.
