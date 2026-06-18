# EQM-087 SUB_TASKS

## Complexity

Class: C5 (orchestrator-direct — central UI gate, tautology-prone). NOT delegated.
Reason:
- the metric harness is the source of truth for every later UI acceptance; a
  tautological / stubbed evaluator would make EQM-090-095 worthless. High shrink risk.
- the hard part (headless Control layout flush) is a subtle infra decision —
  resolved empirically: explicit root size + 2 `process_frame` awaits yields real rects.

## Layout-flush decision (empirically pinned)

```text
- synchronous read after add_child = (0,0); Control layout does NOT flush in _initialize.
- anchor propagation from the Window does NOT stretch a top-level Control to dock size.
- recipe: win.size = dock; root.custom_minimum_size = root.size = dock; add; await frame ×2;
  then global_rect / size / font oracle are valid (verified 420x720 → expanding action label clipped).
```

So the UI metric pass is **frame-stepping**, folded into `run_all.gd` as an async
phase after the synchronous unit tests (one Godot invocation; test.sh unchanged).
`ui_headless/` is excluded from synchronous discovery.

## Task Resolution

| candidate | adopt | note |
|---|---|---|
| editor/testing/eq_ui_layout_snapshot_collector.gd | yes | §3.1 fields per visible Control; ui_metric_* meta + inference; font oracle text_width |
| editor/testing/eq_ui_layout_metric_evaluator.gd | yes | §5 metrics → findings(severity); WARN-only consumption at M1-M3 |
| editor/testing/eq_ui_state_scenario_builder.gd | yes | synthetic Control trees per EDITOR_STATE_MATRIX state (+ deliberately-broken ones) |
| tests/ui_headless/run_ui_metrics.gd | yes | frame-stepping phase: build×size → flush → collect → evaluate → report |
| tests/ui_headless/test_editor_{layout_metrics,state_matrix,interaction_contract}.gd | yes | genuine assertions incl. broken-scenario detection (non-tautology proof) |
| tools/ui_static_audit.py | yes | Pass B source scan (debug literals, float-tick, boolean-text, picker base_type, no-op); WARN-only exit 0 at M1-M3 |
| run_all.gd async UI phase + ui_headless exclusion | yes | one invocation; report under EQ_RUN_OUT |

## Scheduled Task Audit

Next dependency release: EQM-090 (timeline dock MVP) feeds a REAL dock into this
harness. EQM-094/095 (M4/M5) flips WARN-only → P0 hard-fail.
