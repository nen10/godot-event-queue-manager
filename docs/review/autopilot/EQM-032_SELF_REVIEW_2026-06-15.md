# EQM-032 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Added `EQManager`, the scene-local Node facade over `EQRuntime`, with the six signals and the game-loop driver contract. It wires the policy into finish_action (the auto-delegation deferred from EQM-030/031), so the L0 flow is `register → seed → step → turn_ready → finish_action`. Turn readiness suspends the node until `finish_action`; `advance_frame(budget)` time-slices resolution without changing the trace. Registered the node type in the editor plugin and tightened the driver/await contract in `EVENT_MODEL_SEMANTICS.md` §14.

## Changed files

- `addons/event_queue_manager/runtime/eq_manager.gd` — `EQManager extends Node`: signals (queue_changed/event_ready/turn_ready/event_resolved/timeline_advanced/invalid_event_skipped); configure/validate/set_policy/register_actor/seed/step/finish_action/advance_frame; `_awaiting_turn` suspend.
- `addons/event_queue_manager/plugin.gd` — `add_custom_type("EQManager", "Node", …)` / remove.
- `docs/design/EVENT_MODEL_SEMANTICS.md` — §14 aligned to the concrete EQManager API (step/finish_action/advance_frame/suspend).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` — `EQManager: L0`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/runtime/test_eq_manager.gd` — signal flow + suspend, frame-budget determinism, invalid policy, shipped-skip signal.

## Acceptance result — met

| acceptance | result |
|---|---|
| emits queue_changed, event_ready, turn_ready, event_resolved | signal-flow test: turn_ready(actor)/event_resolved/timeline_advanced/queue_changed fire with correct payloads |
| invalid actor policy tested | `configure(base-policy config)` → `validate()` invalid with `POLICY_BASE_INSTANCE` |
| driver contract documented + tested | SEMANTICS §14 (who-advances / suspend / await boundary / frame-budget); suspend (step→null after turn_ready, resumes on finish_action) and frame-budget determinism tested |
| frame-budget / time-sliced advance, determinism preserved | `advance_frame(1)`×12 vs `advance_frame(12)`×1 → byte-identical trace |
| coexists with Godot idioms without breaking determinism | node does not self-drive (consumer calls step/advance_frame); §14 notes SceneTree pause / EditorUndoRedoManager coexistence; budget-invariant trace |

Also: `invalid_event_skipped` signal fires on a shipped-mode orphaned-event skip.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=15 checks=217 failures=0; [api-surface] ok
```

Headless: the node runs as a bare `Node` (no SceneTree needed) for method calls + signal emission; tests `free()` each instance.

## API surface change (explicit golden re-baseline)

`--update`. Diff: new L0 class `EQManager` with 6 signals and 12 public methods (advance_frame/configure/finish_action/is_awaiting_turn/register_actor/runtime/seed/set_mode/set_policy/step/trace_jsonl/validate). No L3 leak.

## Design notes

- **Auto-delegation lands here**, not in EQRuntime: `EQManager.finish_action` calls `policy.on_turn_finished`, keeping EQRuntime (EQM-022) untouched and the policy as a pure rule over primitives.
- **No implicit per-frame drive** by default (consumer calls step/advance_frame); auto-drive can be an opt-in later. Production node bridge (save/load rebind, autoload installer, full multi-domain signals) is EQM-085.

## UX path reduction

- Added: `EQManager` (L0 node) + signals. Narrowed: turn suspend forces the consumer through `finish_action` (no skipping the await boundary). Residual: none.

## Deviations

- None beyond the planned surface addition.

## No sample-only completion

Signal/suspend/determinism/validation asserted directly on a driven node; no sample (the CTB sample battle is EQM-034).

## Repair-now / follow-up

None. Next: EQM-033 (next-N prediction) — a pure hypothetical API that branches a snapshot, advances virtually, and discards, leaving live state unchanged (prediction purity).
