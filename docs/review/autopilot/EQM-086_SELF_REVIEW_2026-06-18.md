# EQM-086 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — UI contract = design). Repair: 0. First Phase 9 task. UI metric adoption **M0** (contract authored).

## Execution summary

Authored the two source-of-truth UI contracts the Phase 9 metric tests gate
against: `docs/ui/EDITOR_UI_CONTRACT.md` (surfaces, required components by role,
forbidden visible text, scroll policy, primary action, empty state, Copy Debug
Report boundary, dead-area exceptions, initial thresholds, action-id registry)
and `docs/ui/EDITOR_STATE_MATRIX.md` (per-scenario expected/forbidden display +
non-text modality). Policy holds the formulas/severities; these docs hold the
project values — the split mandated by UI_TESTABILITY_POLICY §4.

## Changed files

- `docs/ui/EDITOR_UI_CONTRACT.md`, `docs/ui/EDITOR_STATE_MATRIX.md` (new).
- `docs/plan/.../EQM-086_editor_ui_contract/` (SUB_TASKS, IMPLEMENTATION_PLAN).

## Acceptance result — met

| acceptance | result |
|---|---|
| Surfaces defined | 5 surfaces (timeline_dock, order_inspector, config_panel, template_generator, calibration_tab) with purpose + dock/dialog kind |
| Required components | each surface lists roles (`ui_metric_role`) from policy §3.2, required flag, row geometry for timeline |
| Forbidden visible text | per-surface debug set + float-tick + boolean-text-state, tied to §5.5/§5.11 P0 |
| Scenario states | all 12 §4.4 states in EDITOR_STATE_MATRIX with expected/forbidden/modality; + cross-state invariants + text-variant coverage |
| Initial thresholds | §9 values mirrored into the contract as binding (picker/badge/label widths, dead-area, projection N, truncation ratios) |
| docs-only acceptance | no Godot run required; `./tools/test.sh` stays green |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=40 checks=530 failures=0; [api-surface] ok
```

Docs-only: check count unchanged (530), as expected. No code/surface change.

## Design notes (no shrink)

- **Projection integrity made the central, named gate** (§5.9): the contract
  states `ui_order == prediction(N)` as a per-state REQUIRE, not a nicety — the
  one metric that makes a timeline trustworthy. Every order-bearing state repeats it.
- **Non-text modality fully enumerated** (§0 modality vocabulary with glyph ids +
  tooltip-required column) so the M1 harness can assert *presence of icon + tooltip*,
  not just absence of text. Boolean-text-state and float-tick are P0 in §2 invariants.
- **Sample separation is contractual, not implied**: `sample_demo_loaded` /
  `template_dialog_default` pin the `badge.sample` + explicit
  `template.duplicate_to_project` bridge (§5.10), so silent sample→production is testable.
- **calibration_tab is the single debug-exempt surface, conditioned on being
  hidden in normal mode** — keeps the leakage/float metrics strict everywhere else
  without losing a calibration ledger surface.
- **Action-id registry** (UI contract §9) front-loads `ui_action_id`/`effect` for
  every visible button so the no-op-button metric (§5.6) has a closed allow-list.

## UX path reduction

- No new runtime input class. The contract *narrows* future UI: closed role set,
  closed action-id registry, no generic ResourcePicker, no text-only state, single
  debug egress per surface. Residual: thresholds are pre-calibration (calibration =
  later ledger work, declared).

## Deviations

- None. Docs-only M0 as scoped.

## Repair-now / follow-up

None. Next: EQM-087 (UI metric harness — snapshot collector + metric evaluator +
state scenario builder + the three `tests/ui_headless/*` + `ui_static_audit`
extension; adoption M1–M3). That is the harness that consumes these two contracts.
Clear, contract-pinned, mechanical → **Codex 5.5 candidate** (orchestrator pins
the contract + owns the gate), per the run-to-end delegation rule.
