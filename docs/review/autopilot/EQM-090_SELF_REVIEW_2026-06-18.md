# EQM-090 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — first real editor surface = design). Repair: 0. UI metric adoption continues (M1-M3; dock fed through the harness).

## Execution summary

Built the Timeline Preview Dock (`EQTimelineDock`, layer ui) as a projection of
injected state: `set_preview(config, runtime, next_n)` renders one of three states
— empty (no config), validation (invalid config), or the next-N predicted turns.
The rendered order is computed via `EQPrediction.predict_entries` (new, returns
{actor_id, tick} so the dock can show order_index + integer tick_badge). The
dock is fed through the EQM-087 collector in a headless test that compares the
laid-out rows to an INDEPENDENT prediction — projection integrity proven on a real
surface, not asserted by construction.

## Changed files

- `addons/event_queue_manager/runtime/eq_prediction.gd` (edit — `predict_entries`; `predict_turns` delegates, behavior identical).
- `addons/event_queue_manager/editor/timeline_dock.gd` (new — EQTimelineDock, ui), `timeline_dock.tscn` (new).
- `test_project/tests/ui_headless/test_timeline_dock.gd` (new), `run_ui_metrics.gd` (edit — invoke it).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` (+EQTimelineDock ui).
- `tests/golden/api_surface.json` — re-baselined (explicit `--update-golden api_surface`): +`EQTimelineDock` block, +`EQPrediction.predict_entries`. Diff = +47 lines, additive only.

## Acceptance result — met

| acceptance | result |
|---|---|
| user selects project config; dock shows next events | `set_preview(config, runtime, n)` renders predicted turns (order_index/tick/actor/action rows) |
| or explicit unset / validation state | `config==null` → empty_state ("Select a config"); `validate()` errors → validation rows; both tested |
| no silent sample default | no roster is invented; no config → empty_state, 0 rows, empty order (asserted) |
| controls carry `ui_metric_id` metadata | root + summary + count badge + status icon + list + rows + empty + validation + refresh all carry ui_metric_id/role/surface |
| displayed order equals headless prediction (projection integrity) | dock rows read back through the collector == independent `predict_turns`; `dock.order() == expected`; no projection_integrity P0 |
| metric WARN report cited | `[ui_metrics]` runs the dock; report under `.godot_user/test-runs/<id>/ui_metrics.{json,md}` |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=39 checks=549 failures=0   (+11 from the dock test)
  [ui_metrics] scenarios=10 evaluations=20 P0=13 P1=0 WARN=26 (report-only)
  [api-surface] ok (golden re-baselined: +EQTimelineDock, +predict_entries)
```

## Design notes (no shrink)

- **Projection-first, genuinely.** The dock holds no roster; it renders injected
  state. Projection integrity is tested by reading the LAID-OUT rows through the
  collector and comparing to a prediction computed independently in the test — a
  row-ordering/off-by-one/missing-row bug fails it. Not `assert(order == order)`.
- **`predict_entries` over duplicating the predict loop.** The dock needs ticks
  for the contract's integer `tick_badge`; rather than re-derive the schedule in
  the UI, prediction gained a {actor_id, tick} view and `predict_turns` became its
  actor_id-only projection — one prediction path, no UI-side re-derivation, integer
  ticks (float ordering never reaches the UI).
- **Three states, no fallback chain.** null→empty, invalid→validation, valid→order.
  The invalid state surfaces the EQValidation errors (icon + message rows), so a
  missing policy is shown, never silently defaulted (UX_PATH_REDUCTION).
- **Editor-only classes stay out of the headless path.** `EditorResourcePicker`/
  `EditorPlugin` are not referenced; the dock takes its config via `set_preview`,
  and the editor adapter (plugin + picker) is a later integration concern. So the
  whole surface is headless-testable today.

## UX path reduction

- Added: `EQTimelineDock` (ui), `EQPrediction.predict_entries` (L0). Narrowed: dock
  has a single injected entry point and three mutually-exclusive states; no sample
  default. Residual: the editor picker/plugin wiring (EQM-091/095) and tick_badge
  rendering for tickless policies (FixedRound shows the round tick) — both declared.

## Deviations

- The `editor/timeline_dock.tscn` is a minimal script-only scene (children are
  built in `_init`); the dock needs no authored node tree, and this keeps the scene
  loadable without editor-only nodes.
- No `EditorPlugin` registration yet (acceptance lists only dock .gd/.tscn + tests);
  deferred to the editor-integration task.

## Repair-now / follow-up

None. Next: EQM-091 (config panel / policy template surface) per the queue —
the config-selection + validation surface that drives the dock. Orchestrator-direct.
