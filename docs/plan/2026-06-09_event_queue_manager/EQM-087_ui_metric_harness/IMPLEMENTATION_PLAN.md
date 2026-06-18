# EQM-087 IMPLEMENTATION_PLAN

## Files

- `addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd` (new)
- `addons/event_queue_manager/editor/testing/eq_ui_layout_metric_evaluator.gd` (new)
- `addons/event_queue_manager/editor/testing/eq_ui_state_scenario_builder.gd` (new)
- `test_project/tests/ui_headless/run_ui_metrics.gd` (new — frame-stepping phase)
- `test_project/tests/ui_headless/test_editor_layout_metrics.gd` (new)
- `test_project/tests/ui_headless/test_editor_state_matrix.gd` (new)
- `test_project/tests/ui_headless/test_editor_interaction_contract.gd` (new)
- `test_project/tests/run_all.gd` (edit — exclude ui_headless from sync discovery; run async UI phase)
- `tools/ui_static_audit.py` (new — Pass B; WARN-only exit 0)

## Steps

1. Collector: walk a Control tree, emit §3.1 snapshot Dictionary per visible Control.
2. Evaluator: implement §5.1/5.2/5.5/5.6/5.9/5.11 metrics → findings[{severity, surface, metric, message}].
3. Scenario builder: well-formed scenarios (small_queue_3_actors, large_queue_500, no_config_selected, tie_break_same_tick, prediction_stale) + `_broken_*` (truncation, no-op button, projection-misorder, boolean-text-state, debug-leak) to prove the metrics can fail.
4. Runner: for each scenario × {narrow 320x600, normal 420x720}: build → flush (await ×2) → collect → evaluate; aggregate; write `ui_metrics.json` + `.md` under EQ_RUN_OUT.
5. Three test modules: assert (a) well-formed scenarios yield no P0/P1 of the relevant metric, (b) each `_broken_*` IS flagged by the matching metric (non-tautology).
6. run_all.gd: skip `ui_headless` dir in `_discover`; after sync tests, `await` the UI phase, fold its checks into the tester.
7. ui_static_audit.py: scan `addons/event_queue_manager/editor/` + `runtime/ui/`; report debug literals / float-tick formatting / boolean-text-state / generic picker base_type / visible button missing ui_action_id; print findings; exit 0 (M1-M3 WARN-only).

## Gate

- `./tools/test.sh` PASS: `[run_all] failures=0`, `[ui_metrics] P0=.. P1=.. WARN=..` printed, `[api-surface] ok`, `ui_static_audit` exit 0; report files present under the run dir.
- Non-tautology: a `_broken_*` scenario WOULD raise the matching finding (asserted).
- api-surface: `editor/testing/` is test-support; assign layer or exclude per the surface tool's rules.

## Completion checklist

- [ ] collector emits §3.1 fields with real rects (frame-flushed).
- [ ] evaluator implements ≥6 metrics with severity.
- [ ] broken scenarios are detected (assertion proves metrics can fail).
- [ ] report json+md under `.godot_user/test-runs/<id>/`.
- [ ] static audit runs in test.sh, exit 0.
- [ ] `./tools/test.sh` PASS.
