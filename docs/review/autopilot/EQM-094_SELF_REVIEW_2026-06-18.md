# EQM-094 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — calibration loop = design/process). Repair: 0. UI metric adoption **M5 path** (calibration tooling).

## Execution summary

Built the Layout Calibration tab (tweak-and-bake, UI_LAYOUT_CALIBRATION_POLICY) —
a debug-only surface, visible only under `EQ_EDITOR_CALIBRATION=1`, that edits
layout params per `ui_metric_id` live and emits schema-valid `eq_layout_feedback`
JSON for the agent to bake. Documented the ledger (iteration format, bake procedure,
cold-control rule) and a calibration inbox.

## Changed files

- `addons/event_queue_manager/editor/testing/eq_calibration_tab.gd` (new — dev tooling, no class_name → excluded from api-surface + static audit).
- `docs/ui/LAYOUT_CALIBRATION_LEDGER.md` (new), `docs/ui/calibration_inbox/` (new dir).
- `test_project/tests/runtime/test_eq_calibration_tab.gd` (new — sync).

## Acceptance result — met

| acceptance | result |
|---|---|
| debug-only tab edits layout params per `ui_metric_id` | `set_target(surface, controls)` + `edit(id, param, value)` applies live; params = custom_minimum_size.x/.y, size_flags h/v, font_size (§2) |
| Copy Layout Feedback emits schema-valid JSON | `layout_feedback[_json]` → `{kind:eq_layout_feedback, version:1, surface, scenario, dock_size, ui_scale, edited:[{id,param,old,new}], untouched, note, timestamp}`; asserted field-by-field + parses back |
| tab hidden without flag (P0 test) | `EQCalibrationTab.new()` (no flag) → `is_enabled()==false`, `visible==false`; a hidden Control is skipped by the metric collector entirely (§6) |
| bake procedure + cold-control ledger documented | `LAYOUT_CALIBRATION_LEDGER.md` (procedure, iteration format, 3-iteration cold rule, schema) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=42 checks=622 failures=0   (+23: calibration tab)
  [ui_static_audit] scanned 5 file(s) (tab under editor/testing/ correctly excluded)
  [api-surface] ok (no new class_name)
```

## Design notes (no shrink)

- **Flag-gated invisibility is structural.** The tab sets `visible = _enabled` in
  `_init`; with no flag it never renders, so the collector (which skips invisible
  controls) can never surface it in normal mode — the §6 P0 is enforced by absence,
  not a runtime check that could be bypassed. Tested both ways (no flag → hidden,
  injected flag → visible).
- **Feedback carries layout params only.** A dedicated test asserts the JSON
  excludes `res://`, `user://`, `/root/`, `NodePath`, `.gd`, `@` — the §3 rule
  (no file/node/project info) is mechanically verified, not just intended.
- **Edits are reversible and never the source of truth.** `edit` records `{old,new}`;
  `reset_surface` restores every old value and clears the edited list (asserted).
  Only baking persists — the tab cannot silently mutate the shipped layout.
- **`untouched` is real telemetry.** Computed as target ids never edited this
  session → feeds the cold-control rule (3 consecutive untouched → re-evaluate).
- **Copy/Reset have real effects** (no-op audit, §2): Copy emits to the clipboard,
  Reset reverts — both wired with `ui_action_id` + effect.

## UX path reduction

- Added: `EQCalibrationTab` (dev tooling). Narrowed: edits are non-persistent;
  feedback is a closed schema; the tab is invisible by default. Residual: the bake
  side is a documented manual procedure (`manual-optional`, not a CI gate per §6) —
  intentional; calibration must not block the autonomous loop.

## Deviations

- The tab lives in `editor/testing/` (with the metric harness) rather than a
  shipped editor path — it is dev tooling whose packaging is the EQM-103 decision,
  and this keeps it out of the api-surface + static-audit scans (correct: it is the
  one surface allowed raw numbers, §6 of the metric policy).

## Repair-now / follow-up

None. Next: EQM-095 (editor plugin integration / M5 — register the dock + inspector
+ template + calibration tab as an EditorPlugin; final UI adoption). Orchestrator-direct.
