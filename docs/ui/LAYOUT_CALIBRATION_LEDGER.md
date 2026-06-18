# Layout Calibration Ledger

Records each tweak-and-bake iteration (UI_LAYOUT_CALIBRATION_POLICY.md §5). The
calibration tab (`addons/event_queue_manager/editor/testing/eq_calibration_tab.gd`)
is debug-only — visible solely under `EQ_EDITOR_CALIBRATION=1`. A user edits layout
params per `ui_metric_id`, "Copy Layout Feedback" emits schema-valid JSON
(`eq_layout_feedback` v1), the agent bakes it into named constants/theme + updates
`EDITOR_UI_CONTRACT.md` thresholds, and an iteration is appended here.

## Bake procedure (summary)

1. Save the feedback JSON to `docs/ui/calibration_inbox/<date>_<surface>.json`.
2. Apply `edited` as named constants / theme / `custom_minimum_size` (no magic numbers).
3. If a value conflicts with a metric threshold, update `EDITOR_UI_CONTRACT.md` §7
   and record the reason there.
4. Update any test that hard-codes the old threshold to reference the contract;
   deletions need a self-review reason (PROJECT_PROFILE test principles).
5. Append an iteration entry below.
6. Pass `./tools/test.sh`.

## Cold-control rule

A control left **untouched for 3 consecutive** calibrated iterations of its surface
is classified **cold** and queued for UX re-evaluation (simplify/icon-ify, reconsider
necessity, or coarsen the measure). Cold ≠ delete — the decision is made in the
follow-up task's UX candidate matrix.

## Feedback schema (reference)

```json
{
  "kind": "eq_layout_feedback", "version": 1,
  "surface": "timeline_dock", "scenario": "small_queue_3_actors",
  "dock_size": [420, 720], "ui_scale": 1.0,
  "edited": [{"id": "<ui_metric_id>", "param": "custom_minimum_size.x", "old": 60, "new": 96}],
  "untouched": ["<ui_metric_id>"], "note": "", "timestamp": "<iso8601>"
}
```

Layout params only — never file path / node path / project info.

---

## Iterations

_None yet._ The calibration loop is `manual-optional` (UI_LAYOUT_CALIBRATION_POLICY
§6) and is not a CI gate; iterations are appended as real tweak-and-bake sessions
occur. Each entry:

```md
## Iteration <n> — <date> — <surface>

- feedback: docs/ui/calibration_inbox/<file>
- baked: <id / param / new value>
- threshold updates: <EDITOR_UI_CONTRACT.md section>
- untouched: <ui_metric_id list>
```

## Cold-control tracker

| ui_metric_id | surface | consecutive untouched | status |
|---|---|---|---|
| _(populated as iterations accrue)_ | | | |
