# Editor State Matrix

原文: `docs/ui/EDITOR_STATE_MATRIX.md`

Event Queue Manager editor の state-dependent display contract です。scenario state (UI_LAYOUT_METRIC_TEST_POLICY §4.4) ごとに、**expected display**、**forbidden display** (state contradictions, §5.8)、**modality** (icon/checkbox/badge。boolean text は禁止, §5.11) を固定します。

`tests/ui_headless/test_editor_state_matrix.gd` はこのファイルを根拠に assert します。Surfaces/components/thresholds は `EDITOR_UI_CONTRACT.md` にあります。

Adoption: **M0** (contract authored)。

---

## 0. Modality vocabulary

state はまず non-text modality で表示します。status glyph の `ui_metric_id` は、test が presence + tooltip を assert できるように与えられます。

| modality key | render | tooltip required | example use |
|---|---|---|---|
| `icon.ok` | check / filled dot | yes | config valid |
| `icon.error` | cross / alert | yes | validation errors present |
| `icon.warn` | caution | yes | non-blocking warning |
| `icon.neutral` | hollow dot | yes | nothing selected / no config |
| `badge.tick` | integer chip | no (値だけで明らか) | tick number |
| `badge.count` | integer chip | optional | queue size |
| `badge.sample` | "sample" mark | yes | sample/demo artifact |
| `glyph.stale` | `status_icon` 上の stale mark | yes | prediction stale |
| `glyph.fresh` | `status_icon` 上の fresh mark | yes | prediction fresh |
| `glyph.draft` | draft/edit mark | yes | transaction draft active |
| `glyph.armed` | armed/lightning mark | yes | reaction armed |
| `icon.tie` | tie-break mark (`cause_icon`) | yes | same-tick entries |

**全体で禁止 (normal mode, P0):** boolean state を text として render すること (`true/false`, `ON/OFF`, `有効/無効`, `stale: true`, `valid: false`) と、float tick (`3.0`)。

---

## 1. State matrix

Columns: 主に影響を受ける surface(s) · expected display · forbidden display (contradiction) · modality。

### `no_config_selected`
- surface: `config_panel`, `timeline_dock`
- expected: `config_panel.empty_state` visible。`status_icon` = `icon.neutral`。`validation_list` empty。`timeline_dock.empty_state` visible、0 rows。
- forbidden: `config != null` なのに "No config selected"。任意の `icon.ok`。任意の timeline row。
- modality: `icon.neutral`。

### `invalid_config_missing_policy`
- surface: `config_panel`
- expected: `status_icon` = `icon.error`。`validation_list` に >=1 の `validation_row` があり、`icon.error` (missing policy) を持つ。`timeline_dock` は `empty_state` を表示する (valid prediction なし)。
- forbidden: errors > 0 なのに `icon.ok` (P0 §5.8)。invalid なのに empty `validation_list`。
- modality: `icon.error` + per-row `icon.error`。

### `valid_config_no_actors`
- surface: `config_panel`, `timeline_dock`
- expected: `config_panel.status_icon` = `icon.ok`。`validation_list` clean。`timeline_dock.empty_state` visible ("no actors")、0 rows。
- forbidden: queue empty なのに timeline rows > 0 (P0 §5.8)。`icon.error`。
- modality: `icon.ok` + `empty_state`。

### `small_queue_3_actors`
- surface: `timeline_dock`
- expected: exactly 3 `timeline_row` (または `min(N,3)`)。`ui_order == prediction`。各 row は `badge.tick`, `actor_label`, `action_label` を持つ。`order_index` は 1..3。`status_icon` = `glyph.fresh`。
- forbidden: order != prediction (P0 §5.9)。float tick。horizontal scroll。normal で `actor_label` width < `min_actor_label_width_normal`。
- modality: `badge.tick`, `order_index`, `glyph.fresh`。

### `tie_break_same_tick`
- surface: `timeline_dock`
- expected: tie している rows は同じ `badge.tick` を共有する。各 tied row は tie-break rule 名を tooltip に持つ `icon.tie` (`cause_icon`) を持つ。visible order == headless tie-break order。
- forbidden: identical-tick rows に tie indicator がない (WARN→ここでは contract として required)。order != prediction。
- modality: `icon.tie` + tooltip; `badge.tick`。

### `large_queue_500_entries`
- surface: `timeline_dock`
- expected: visible rows == `min(default_next_n_for_projection_test, 500)` (=10)。`scroll_root` は vertically scroll する。`summary` は `badge.count` = 500 を表示。uniform `row_height`。horizontal scroll なし。
- forbidden: 500 rows すべてを render すること (N に window しなければならない)。non-uniform row height (P0 §5.2)。horizontal scroll。
- modality: `badge.count`, vertical scroll only。

### `prediction_fresh`
- surface: `timeline_dock`
- expected: `status_icon` = `glyph.fresh`。rows は current snapshot prediction と一致。
- forbidden: fresh なのに `glyph.stale`。"fresh: true" text。
- modality: `glyph.fresh`。

### `prediction_stale`
- surface: `timeline_dock`
- expected: `status_icon` = `glyph.stale` (last predict 以降 snapshot が変化)。`primary_action` `timeline.refresh_prediction` enabled。
- forbidden: `prediction_stale == true` なのに `glyph.stale` がない (P0 §5.8)。stale を text として表示。
- modality: `glyph.stale` + tooltip; enabled refresh action。

### `transaction_draft_active`
- surface: `timeline_dock`, `order_inspector`
- expected: `status_icon` 上の `glyph.draft`。commit/rollback actions は enabled、または disabled の場合 condition tooltip を持つ (§5.6 WARN→contract requires tooltip)。
- forbidden: `draft_active == true` なのに commit/rollback が disabled かつ tooltip なし。draft を "draft: true" text として表示。
- modality: `glyph.draft` + tooltip。

### `reaction_armed_visible`
- surface: `timeline_dock`
- expected: armed entry は tooltip ("reaction armed: <condition>") 付きの `glyph.armed` (`cause_icon`) を持つ。order は prediction と一致したまま。
- forbidden: armed を text ("armed: true") として表示。indicator による order distortion。
- modality: `glyph.armed` + tooltip。

### `template_dialog_default`
- surface: `template_generator`
- expected: default template selected。`summary` preview shown。`primary_action` `template.generate` enabled。`secondary_action` `template.duplicate_to_project` present。
- forbidden: blank dialog body (dead-area fail)。generated template が silent に production slot を満たすこと。
- modality: preview section + enabled primary。

### `sample_demo_loaded`
- surface: `template_generator`, `config_panel`
- expected: artifact は `badge.sample` を持つ。`template.duplicate_to_project` なしに `config_panel.config_slot` を満たさない。
- forbidden (P0 §5.10): sample が production config として表示されること。sample が silent に production required slot に入ること。
- modality: `badge.sample` + tooltip。

---

## 2. State 横断 invariant (every state, normal mode)

```text
- order を表示する surface では ui_order == prediction(N) (§5.9, P0)。
- visible debug_label_count == 0 (§5.5, P0)。debug は debug.copy_report からだけ。
- boolean_text_labels == 0 (§5.11, P0)。
- float tick display == 0 (§5.5, P0)。
- calibration_tab not visible (§6.1, P0)。
- すべての status_icon/cause_icon は tooltip を持つ (§5.11 WARN→contract required)。
- sample artifact は明示的な duplicate step なしに production required slot に到達しない (§5.10, P0)。
```

## 3. Text variant coverage

各 order-bearing state は text variants (UI_LAYOUT_METRIC_TEST_POLICY §4.3) でも評価されます: `en_short`, `ja_short`, `ja_long`, `long_actor_names`, `long_action_names`。Expectation: titles / `actor_label` は tooltip 付きで elide してよい。ただし **horizontal scroll なし**、**normal width で required-title truncation なし** (§5.1 FAIL)、tie/stale/armed glyph は text length に関係なく visible のまま。
