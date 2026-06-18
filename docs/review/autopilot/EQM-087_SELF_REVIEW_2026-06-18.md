# EQM-087 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — central UI gate, NOT delegated; tautology-prone). Repair: 0. UI metric adoption **M1-M3** (harness live, WARN-only).

## Execution summary

Built the UI metric harness that consumes the EQM-086 contracts: a headless
layout snapshot collector (Pass A), a metric evaluator (§5), a synthetic scenario
builder (good + deliberately-broken), a frame-stepping runner folded into
`run_all.gd`, three assertion modules, and the Python static audit (Pass B). The
hard part — headless Control layout only resolves across process frames — was
solved empirically (explicit root size + 2 `process_frame` awaits) and is the
reason the UI phase is async and `ui_headless/` is excluded from the synchronous
unit discovery.

## Changed files

- `addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd`,
  `eq_ui_layout_metric_evaluator.gd`, `eq_ui_state_scenario_builder.gd` (new; no
  `class_name` — test-support internals, deliberately kept out of the public api-surface).
- `test_project/tests/ui_headless/run_ui_metrics.gd` + `test_editor_layout_metrics.gd`,
  `test_editor_state_matrix.gd`, `test_editor_interaction_contract.gd` (new).
- `test_project/tests/run_all.gd` (edit — exclude `ui_headless/`; run async UI phase).
- `tools/ui_static_audit.py` (new — Pass B; report-only at M1-M3, `--enforce` for M4/M5).

## Acceptance result — met

| acceptance | result |
|---|---|
| static audit runs inside `./tools/test.sh` | `[ui_static_audit] scanned 2 file(s) P0=0 P1=0`, exit 0 |
| collector produces snapshot JSON for a synthetic scenario tree | `ui_metrics.json` written; §3.1 fields with frame-flushed real rects (420w fill, expanding clipped action label) |
| evaluator reports metrics WARN-only | findings are report-only; build gated only by the modules' structural assertions; `[ui_metrics] P0=13 P1=0 WARN=26 (report-only, M1-M3)` |
| report written under `.godot_user/test-runs/` | `ui_metrics.json` + `ui_metrics.md` present in the run dir |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=39 checks=538 failures=0   (+8 from the 3 UI modules)
  [ui_metrics] scenarios=10 evaluations=20 P0=13 P1=0 WARN=26 (report-only)
  [ui_static_audit] P0=0 P1=0 ; [api-surface] ok
```

## Design notes (no shrink)

- **Godot is the layout oracle** (policy §2.2): rects are read after a real
  frame-flush, never recomputed in Python. The 2-frame recipe was verified before
  building anything (probe runs), so the collector reads true geometry.
- **Non-tautology is structural, not asserted by fiat.** Six `broken_*` scenarios
  each inject exactly one defect (starved title, unwired button, mis-ordered rows,
  boolean-text state, res:// leak, float tick); the modules assert each is flagged
  AND that the `good_*` twins are P0-clean. Verified: all 13 P0 belong to broken
  scenarios; zero good-scenario P0. A broken collector/evaluator fails these.
- **Projection integrity is exercised as the central gate** (§5.9): ui_order is
  read from row global-y order and compared to the supplied prediction; the
  windowed 500→10 scenario proves windowing preserves integrity; the misorder
  scenario proves a distorted timeline is caught.
- **Severity is width-aware** (§6): the starved title is P0 at normal, WARN at
  narrow — asserted both ways, so the threshold logic itself is covered.
- **Button padding model corrected**: a Button's min size already includes theme
  content margins; subtracting extra padding forged truncation. Set to 0 so only a
  genuinely width-constrained control reads ratio>1 (caught the false positive in
  the first run; good scenarios went 2 P0 → 0).
- **WARN-only semantics are real**: P0/P1 findings do not fail the build at M1-M3;
  only harness correctness does. EQM-094/095 (M4/M5) flips this via the existing
  `--enforce` flag + finding-severity gating — a localized change, the structure is ready.
- **api-surface kept clean**: the harness classes carry no `class_name`, so they
  are not part of the shipped public surface (their packaging is the EQM-103
  decision); the runner/tests preload them by path.

## UX path reduction

- No new runtime input class. The harness narrows future UI work: every surface
  must pass the same collector/evaluator; defects are mechanically detected, not
  eyeballed. Residual: only 6 metrics implemented of §5's full set (truncation,
  timeline geometry, debug leakage+float, no-op button, modality, projection) —
  the highest-value, computable-from-synthetic ones; the rest (scroll reachability
  §5.3, dead area §5.4, picker specificity §5.7 deep, sample separation §5.10)
  attach when the real surfaces exist (EQM-090+), each a new evaluator function.

## Deviations

- Folded the UI phase into `run_all.gd` rather than a second Godot invocation in
  `test.sh` — one process, test.sh unchanged, `[ui_metrics]` line in the same log.
  Equivalent acceptance, less moving infra.

## Repair-now / follow-up

None. Next: EQM-090 (Timeline Preview Dock MVP) — the first REAL editor surface,
fed through this harness (projection integrity on a live dock). Orchestrator-direct
(editor UI = design surface).
