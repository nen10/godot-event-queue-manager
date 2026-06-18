# EQM-090 IMPLEMENTATION_PLAN

Class: C4 (orchestrator-direct — first real editor surface = design). NOT delegated.

## Files

- `addons/event_queue_manager/runtime/eq_prediction.gd` (edit — add `predict_entries`; `predict_turns` delegates).
- `addons/event_queue_manager/editor/timeline_dock.gd` (new — EQTimelineDock, layer ui).
- `addons/event_queue_manager/editor/timeline_dock.tscn` (new — minimal scene).
- `test_project/tests/ui_headless/test_timeline_dock.gd` (new — real-dock projection/state, run in UI phase).
- `test_project/tests/ui_headless/run_ui_metrics.gd` (edit — invoke the dock test).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` (+EQTimelineDock ui; predict_entries).
- `tests/golden/api_surface.json` (explicit `--update`).

## Design (projection-first)

The dock is a projection of injected state — `set_preview(config, runtime, next_n)`:
- `config == null` → `empty_state` ("Select a config"), no rows (no silent sample default).
- `config.validate()` errors → `validation_list` rows (icon+message), no timeline rows.
- valid → rows from `EQPrediction.predict_entries(runtime, next_n)`; order_index + tick_badge + actor_label + action_label.

Editor `EditorResourcePicker` wiring is a thin editor-side adapter (EQM-091/plugin)
that calls `set_preview`; headless tests inject config+runtime directly. All controls
carry `ui_metric_id/role/surface` metadata. `Refresh` button = `timeline.refresh_prediction`.

## Projection integrity (genuine, non-tautological)

The dock test feeds the REAL dock through the EQM-087 collector, reads `ui_order`
from the laid-out rows, and compares to an INDEPENDENT `EQPrediction.predict_turns`
(computed in the test). A row-building bug (wrong order, off-by-one, missing rows)
→ `projection_integrity` P0. Empty/validation states asserted too.

## Gate

- `./tools/test.sh` PASS; `[ui_metrics]` includes the dock; dock test asserts
  ui_order == prediction, empty/validation states, metadata present; api-surface ok
  after `--update`; metric report cites the dock scenario.

## Checklist

- [ ] predict_entries returns {actor_id, tick}; predict_turns identical behavior.
- [ ] dock renders order/empty/validation; no silent sample default.
- [ ] all controls carry ui_metric metadata.
- [ ] real-dock projection integrity asserted vs independent prediction.
- [ ] golden re-baselined (explicit --update) + self-review note.
- [ ] `./tools/test.sh` PASS.
