# Editor State Matrix

State-dependent display contract for the Event Queue Manager editor. For each
scenario state (UI_LAYOUT_METRIC_TEST_POLICY §4.4) this fixes the **expected
display**, the **forbidden display** (state contradictions, §5.8), and the
**modality** (icon/checkbox/badge — never boolean text, §5.11).

`tests/ui_headless/test_editor_state_matrix.gd` asserts against this file.
Surfaces/components/thresholds live in `EDITOR_UI_CONTRACT.md`.

Adoption: **M0** (contract authored).

---

## 0. Modality vocabulary

State is shown by a non-text modality first; the `ui_metric_id` for the status
glyph is given so tests can assert presence + tooltip.

| modality key | render | tooltip required | example use |
|---|---|---|---|
| `icon.ok` | check / filled dot | yes | config valid |
| `icon.error` | cross / alert | yes | validation errors present |
| `icon.warn` | caution | yes | non-blocking warning |
| `icon.neutral` | hollow dot | yes | nothing selected / no config |
| `badge.tick` | integer chip | no (value self-evident) | tick number |
| `badge.count` | integer chip | optional | queue size |
| `badge.sample` | "sample" mark | yes | sample/demo artifact |
| `glyph.stale` | stale mark on `status_icon` | yes | prediction stale |
| `glyph.fresh` | fresh mark on `status_icon` | yes | prediction fresh |
| `glyph.draft` | draft/edit mark | yes | transaction draft active |
| `glyph.armed` | armed/lightning mark | yes | reaction armed |
| `icon.tie` | tie-break mark (`cause_icon`) | yes | same-tick entries |

**Forbidden everywhere (normal mode, P0):** any boolean state rendered as text
(`true/false`, `ON/OFF`, `有効/無効`, `stale: true`, `valid: false`), and any
float tick (`3.0`).

---

## 1. State matrix

Columns: surface(s) primarily affected · expected display · forbidden display
(contradiction) · modality.

### `no_config_selected`
- surface: `config_panel`, `timeline_dock`
- expected: `config_panel.empty_state` visible; `status_icon` = `icon.neutral`;
  `validation_list` empty; `timeline_dock.empty_state` visible, 0 rows.
- forbidden: "No config selected" while `config != null`; any `icon.ok`; any timeline row.
- modality: `icon.neutral`.

### `invalid_config_missing_policy`
- surface: `config_panel`
- expected: `status_icon` = `icon.error`; `validation_list` has >=1
  `validation_row` with `icon.error` (missing policy); `timeline_dock` shows
  `empty_state` (no valid prediction).
- forbidden: `icon.ok` while errors > 0 (P0 §5.8); empty `validation_list` while invalid.
- modality: `icon.error` + per-row `icon.error`.

### `valid_config_no_actors`
- surface: `config_panel`, `timeline_dock`
- expected: `config_panel.status_icon` = `icon.ok`; `validation_list` clean;
  `timeline_dock.empty_state` visible ("no actors") with 0 rows.
- forbidden: timeline rows > 0 while queue empty (P0 §5.8); `icon.error`.
- modality: `icon.ok` + `empty_state`.

### `small_queue_3_actors`
- surface: `timeline_dock`
- expected: exactly 3 `timeline_row` (or `min(N,3)`); `ui_order == prediction`;
  each row has `badge.tick`, `actor_label`, `action_label`; `order_index` 1..3;
  `status_icon` = `glyph.fresh`.
- forbidden: order != prediction (P0 §5.9); float tick; horizontal scroll;
  `actor_label` width < `min_actor_label_width_normal` at normal.
- modality: `badge.tick`, `order_index`, `glyph.fresh`.

### `tie_break_same_tick`
- surface: `timeline_dock`
- expected: tied rows share the same `badge.tick`; each tied row carries
  `icon.tie` (`cause_icon`) with a tooltip naming the tie-break rule; visible
  order == headless tie-break order.
- forbidden: identical-tick rows with no tie indicator (WARN→ here required as
  contract); order != prediction.
- modality: `icon.tie` + tooltip; `badge.tick`.

### `large_queue_500_entries`
- surface: `timeline_dock`
- expected: visible rows == `min(default_next_n_for_projection_test, 500)` (=10);
  `scroll_root` scrolls vertically; `summary` shows `badge.count` = 500;
  uniform `row_height`; no horizontal scroll.
- forbidden: rendering all 500 rows (must window to N); non-uniform row height
  (P0 §5.2); horizontal scroll.
- modality: `badge.count`, vertical scroll only.

### `prediction_fresh`
- surface: `timeline_dock`
- expected: `status_icon` = `glyph.fresh`; rows match current snapshot prediction.
- forbidden: `glyph.stale` while fresh; "fresh: true" text.
- modality: `glyph.fresh`.

### `prediction_stale`
- surface: `timeline_dock`
- expected: `status_icon` = `glyph.stale` (snapshot changed since last predict);
  `primary_action` `timeline.refresh_prediction` enabled.
- forbidden: `prediction_stale == true` but no `glyph.stale` (P0 §5.8); stale as text.
- modality: `glyph.stale` + tooltip; enabled refresh action.

### `transaction_draft_active`
- surface: `timeline_dock`, `order_inspector`
- expected: `glyph.draft` on `status_icon`; commit/rollback actions either
  enabled or, if disabled, carry a condition tooltip (§5.6 WARN→contract requires
  the tooltip).
- forbidden: `draft_active == true` but commit/rollback disabled with no tooltip;
  draft shown as "draft: true" text.
- modality: `glyph.draft` + tooltip.

### `reaction_armed_visible`
- surface: `timeline_dock`
- expected: the armed entry carries `glyph.armed` (`cause_icon`) with a tooltip
  ("reaction armed: <condition>"); order still == prediction.
- forbidden: armed shown as text ("armed: true"); order distortion by the indicator.
- modality: `glyph.armed` + tooltip.

### `template_dialog_default`
- surface: `template_generator`
- expected: default template selected; `summary` preview shown; `primary_action`
  `template.generate` enabled; `secondary_action` `template.duplicate_to_project` present.
- forbidden: blank dialog body (dead-area fail); a generated template silently
  satisfying a production slot.
- modality: preview section + enabled primary.

### `sample_demo_loaded`
- surface: `template_generator`, `config_panel`
- expected: the artifact carries `badge.sample`; it does NOT satisfy
  `config_panel.config_slot` without `template.duplicate_to_project`.
- forbidden (P0 §5.10): sample shown as a production config; sample silently in a
  production required slot.
- modality: `badge.sample` + tooltip.

---

## 2. Cross-state invariants (every state, normal mode)

```text
- ui_order == prediction(N) on any surface that displays order (§5.9, P0).
- visible debug_label_count == 0 (§5.5, P0); debug only via debug.copy_report.
- boolean_text_labels == 0 (§5.11, P0).
- float tick display == 0 (§5.5, P0).
- calibration_tab not visible (§6.1, P0).
- every status_icon/cause_icon has a tooltip (§5.11 WARN→required by contract).
- sample artifacts never reach a production required slot without the explicit
  duplicate step (§5.10, P0).
```

## 3. Text variant coverage

Each order-bearing state is additionally evaluated under the text variants
(UI_LAYOUT_METRIC_TEST_POLICY §4.3): `en_short`, `ja_short`, `ja_long`,
`long_actor_names`, `long_action_names`. Expectation: titles/`actor_label` may
elide with tooltip; **no horizontal scroll**, **no required-title truncation at
normal width** (§5.1 FAIL), tie/stale/armed glyphs remain visible regardless of text length.
