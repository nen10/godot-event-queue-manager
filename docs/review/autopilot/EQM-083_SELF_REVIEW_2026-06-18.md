# EQM-083 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — first UI surface, sets the projection pattern). Repair: 0.

## Execution summary

Built `EQTimelineHud` (player-facing) and `EQDebugOverlay` (opt-in consumer debug), both projection-first: they render an injected order verbatim and never recompute order on the UI side. Added the `ui` API-surface layer.

## Changed files

- `addons/event_queue_manager/runtime/ui/eq_timeline_hud.gd`, `eq_timeline_hud.tscn`, `eq_debug_overlay.gd` (new).
- `tools/check_api_surface.py` (+`ui` layer, EQTimelineHud/EQDebugOverlay) + `docs/design/API_SURFACE.md`.
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/ui_headless/test_eq_timeline_hud.gd` (new dir).

## Acceptance result — met

| acceptance | result |
|---|---|
| renders injected prediction (projection integrity) | `set_state(order)` → `hud.order()` and the row Controls equal the injected order; the HUD never calls a scheduler/policy |
| updates on queue_changed | `bind(manager, depth)` connects `queue_changed` → re-injects `EQPrediction.predict_turns` (headless source, not UI re-sort) |
| explicit stale state while presentation deferred | `set_stale(true)` shows a non-text stale indicator (badge), `is_stale()` true |
| controls carry ui_metric_id | rows + badges + stale/empty markers carry `ui_metric_id`/`ui_metric_role`/`ui_metric_surface` |
| no UI-side order recomputation | the HUD holds the injected order and renders it; tests assert order == injected |
| localizable + non-text modality | labels are localizable keys (`EQ_TIMELINE_*`); position is a number badge, stale is a glyph icon (not colour-only) |
| opt-in debug overlay (live order + why-next) | `EQDebugOverlay.set_state(order, explanations)` renders order + decided_by (explanation-as-data) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=37 checks=504 failures=0; [api-surface] ok
```

Tested via structure/state/metadata (UI_TESTABILITY L4 projection integrity + L2 state matrix), not screenshots.

## Design notes (no shrink)

- **Projection-first, not a re-sort**: `set_state` is the only render input; `bind` re-injects the *prediction* (the headless truth) on queue_changed. The HUD has no path to recompute order — proven by it never importing/holding a scheduler.
- **Non-text modality**: order is a number badge and stale is a glyph, so the HUD is not colour-only (colorblind/screen-reader safety).
- **Explicit empty/stale states** (markers, not silent blanks) per UX_PATH_REDUCTION.
- Full UI metric harness (collector/evaluator) is EQM-087; this task tags controls with the metadata it will read and proves projection integrity now.

## UX path reduction

- Added: `EQTimelineHud`/`EQDebugOverlay` (ui layer, opt-in). Narrowed: render is injection-only (no UI recomputation); empty/stale are explicit. Residual: none.

## Deviations

- Added a `ui` API-surface layer (the first runtime UI). Recorded.

## Repair-now / follow-up

None. Next: EQM-084 (dogfood vertical slice) — a minimal playable Action Resolution game using only the public API, with its own golden trace + friction report. This also exercises the Phase 8 records being produced by a real consumer (the boundary observation from the Phase 8 review). Orchestrator-direct.
