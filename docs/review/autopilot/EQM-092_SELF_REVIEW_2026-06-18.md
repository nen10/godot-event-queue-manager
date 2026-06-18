# EQM-092 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — template/sample separation = design). Repair: 0.

## Execution summary

Productized the EQM-084 dogfood slice into the shipped demo
(`demos/action_resolution/demo_battle.gd`) and built the template generator
(`EQTemplateGenerator`, ui, template_generator surface) that authors it as project
assets with explicit sample separation: `generate()` yields a badged sample (not
in the project); `duplicate_to_project()` is the only bridge that writes project
assets. Added the §5.10 sample-separation metric to the evaluator so the badge is
enforced on the real surface.

## Changed files

- `demos/action_resolution/demo_battle.gd` (new — public-API demo; adds presentation-flush tracing).
- `addons/event_queue_manager/editor/template_generator.gd` (new — EQTemplateGenerator, ui).
- `addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd` (+is_sample), `eq_ui_layout_metric_evaluator.gd` (+§5.10 sample_separation).
- `test_project/tests/runtime/test_action_resolution_demo.gd` (new — sync), `test_project/tests/ui_headless/test_template_generator.gd` (new — UI phase) + `run_ui_metrics.gd` (edit).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` (+EQTemplateGenerator ui).
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`): +EQTemplateGenerator. Additive.

## Acceptance result — met

| acceptance | result |
|---|---|
| template creates project assets | `duplicate_to_project(target)` writes `action_resolution_config.tres` via ResourceSaver; test asserts the file exists + loads + validates |
| not hidden sample defaults | `generate()` is a badged sample with `satisfies_production_slot()==false`; no production path without the explicit duplicate step; §5.10 metric enforces the badge |
| generated demo uses reservation/trigger/presentation APIs | demo trace shows `reaction_fired` (armed reservation + trigger) and `presentation_flush` (buffer output); manifest `uses_apis` lists reservation/trigger/presentation; all asserted |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=41 checks=598 failures=0   (+20: demo + template generator)
  [ui_metrics] ... (now also evaluates the template_generator surface; §5.10 added)
  [api-surface] ok (golden re-baselined: +EQTemplateGenerator)
```

## Design notes (no shrink)

- **Sample separation is mechanical, two-step, and metric-enforced.** generate →
  sample (badged, `ui_is_sample` meta), duplicate_to_project → project assets. The
  new §5.10 evaluator metric fails a surface that shows a sample with no
  `badge_sample`. The production-slot guarantee is asserted in logic
  (`satisfies_production_slot()` false until the explicit duplicate).
- **The demo is the dogfood, productized — not a reimplementation.** Same public-API
  wiring proven in EQM-084 (AP turns, armed counter reservation+trigger, effects,
  seeded RNG), now with presentation FLUSH tracing so the demo exercises
  presentation OUTPUT, and `build_config()`/`USES_APIS` for the generator + tests.
- **No frozen golden for the demo.** The demo test asserts structure + determinism
  (two runs byte-identical), not a golden fixture — avoids coupling a demo to the
  golden-trace update policy while still proving determinism.
- **Real asset creation, not a stub.** duplicate_to_project actually serializes an
  EQConfig to disk; the test loads it back and validates it — "creates project
  assets" is verified end to end, not asserted.

## UX path reduction

- Added: `EQTemplateGenerator` (ui), the demo, §5.10 metric. Narrowed: the only
  sample→production path is the explicit duplicate; generate is scratch-only.
  Residual: the editor dialog chrome (OptionButton for multiple templates) is a
  single-template MVP; more templates attach to the same generate/duplicate seam.

## Deviations

- The generator is a `VBoxContainer` surface (logic + UI in one), consistent with
  the dock/inspector pattern; the demo is a `RefCounted` with a static `run_trace`
  (headless-testable), not a scene — a scene wrapper can wrap it later.

## Repair-now / follow-up

None. Next: EQM-093 (config panel surface — policy/tie-break selection + validation,
UI metric adoption continues). Orchestrator-direct (config surface = design).
