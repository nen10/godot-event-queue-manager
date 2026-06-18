# EQM-093 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — acceptance gate semantics = design). Repair: 0. UI metric adoption **M4** (P0 enforced).

## Execution summary

Flipped the UI metric harness from report-only (M1-M3) to **M4 enforcement**: a P0
finding on any non-broken scenario now FAILS the build, and the static audit runs
`--enforce`. Completed the enforced metric set by adding the two acceptance metrics
the evaluator lacked — §5.3 scroll reachability and §5.8 state contradiction — so
the full list (no-op, scroll, contradiction, debug leakage, float tick, projection
integrity, sample separation) is gated. The `broken_*` scenarios stay self-tests
(they MUST produce P0) and are excluded from enforcement.

## Changed files

- `addons/event_queue_manager/editor/testing/eq_ui_layout_metric_evaluator.gd` (+§5.3 scroll_reachability, +§5.8 state_contradiction).
- `test_project/tests/ui_headless/run_ui_metrics.gd` (M4 `_enforce_p0` gate; adoption strings).
- `tools/test.sh` (ui_static_audit `--enforce`).
- `docs/ui/EDITOR_UI_CONTRACT.md` (adoption → M4).

## Acceptance result — met

| acceptance (enforced as FAIL) | result |
|---|---|
| no-op buttons | `noop_button` P0 enforced (visible enabled button w/o pressed connection or ui_action_id) |
| scroll reachability | `scroll_reachability` P0 added: content min-height > viewport with no scroll container; primary action stranded below viewport |
| state contradiction | `state_contradiction` P0 added: empty_state + rows, empty_state + validation, validation + order co-occurring |
| debug leakage / float tick | `debug_leakage` P0 enforced (debug text kind; tick `N.M` float form) |
| projection integrity | `projection_integrity` P0 enforced (ui_order != prediction; wrong row count) |
| sample fallback | `sample_separation` P0 enforced (sample artifact not badged) |
| across the scenario matrix | `_enforce_p0` iterates every non-broken scenario × dock; any P0 → `t.ok(false)`; real surfaces gated by their own dedicated tests |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [ui_static_audit] scanned 5 file(s) P0=0 mode=enforce
  [ui_metrics] scenarios=10 evaluations=20 P0=13 P1=0 WARN=26 (M4: P0 enforced on real/good surfaces)
  [run_all] files=41 checks=599 failures=0   (+1: the M4 gate assertion)
  [api-surface] ok (no new class; no golden change)
```

## Design notes (no shrink)

- **Enforcement is genuine, not a relabel.** `_enforce_p0` actually fails the build
  on a non-broken P0 (a `t.ok(false)` per violation). The gate passes today because
  the good scenarios + real surfaces are P0-clean (independently verified — the 13
  P0 belong entirely to `broken_*`). A future surface that regresses to any enforced
  P0 fails automatically.
- **`broken_*` correctly excluded.** They are the evaluator's non-tautology proof —
  they MUST raise P0 — so enforcing them would invert their purpose. The three
  structural modules still assert each broken scenario produces its P0.
- **Two new metrics computed from real geometry.** Scroll reachability uses the
  container's combined_minimum_size (the natural/unclamped content height) vs the
  viewport — so a 500-row no-scroll list fails while a windowed 10-row list passes.
  State contradiction reads mutually-exclusive role visibility from the snapshot —
  no extra scenario annotations needed.
- **Static audit enforces too.** `--enforce` makes a source-level P0 (debug literal,
  boolean-text state, float-tick format, generic picker) fail the build; it scans
  the 5 real UI scripts (editor surfaces + runtime HUD/overlay), all clean.

## UX path reduction

- No new input class. Narrowed: WARN-only → FAIL for the enforced P0 set; the editor
  surfaces can no longer regress on these silently. Residual: P1 severities remain
  report (not yet gated); calibration of thresholds is EQM-094/095 (M5).

## Deviations

- The M4 gate runs inside the folded UI phase (one Godot invocation) rather than a
  separate test.sh stage — consistent with EQM-087's structure; the static-audit
  `--enforce` is the test.sh-level half of the gate.

## Repair-now / follow-up

None. Next: EQM-094 (Layout Calibration Loop — debug-only calibration tab + ledger;
tab hidden without a flag is itself a P0 test). Orchestrator-direct.
