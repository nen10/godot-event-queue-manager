# Editor UI Contract

Source-of-truth for the Event Queue Manager editor UI. The UI metric tests
(`tests/ui_headless/*`, `tools/ui_static_audit.py`) gate against **this file**;
`docs/devflow/policy/UI_LAYOUT_METRIC_TEST_POLICY.md` defines the *formulas /
severities*, this file holds the *project-specific values* (surfaces, required
components, forbidden text, thresholds, dead-area exceptions). State-dependent
display lives in `EDITOR_STATE_MATRIX.md`.

Adoption stage: **M5** (EQM-095) — the metric harness enforces **P0 and P1** as a
build FAIL on real/good surfaces (P0: no-op button, scroll reachability, state
contradiction, debug leakage, float tick, projection integrity, sample separation;
P1: row geometry, non-primary truncation, picker width, text-only status); the
static audit runs `--enforce`. (Contract M0=EQM-086, harness M1-M3=EQM-087, first
surfaces=EQM-090/091/092, P0 gate M4=EQM-093, calibration loop=EQM-094.)
Changes to visible UI MUST update this file first (UI_LAYOUT_METRIC_TEST_POLICY §7.1).

---

## 0. Principles (binding)

- The editor UI is a **projection of injected headless state** — never a second
  source of truth. The order a timeline shows MUST equal `prediction(N)` from the
  same snapshot (§5.9 projection integrity, the central gate).
- **State is shown by non-text modality first** (icon / checkbox / badge /
  progress); text is for names and tooltips, not for status. Boolean state as
  text (`true/false`, `ON/OFF`, `有効/無効`) is a P0 failure (§5.11).
- **No debug leakage in normal mode.** Debug detail is reachable only through a
  per-surface `Copy Debug Report` action (§5.5). Float ticks never reach the UI.
- **Sample ≠ production.** Sample/demo templates reach production config only via
  an explicit `Duplicate To Project` step, never silent fallback (§5.10).
- **dev fail-fast / shipped fail-safe** is a runtime concern; the editor always
  runs in dev-adjacent "normal mode" for these metrics. `calibration_tab` is the
  only surface allowed to show raw numeric/debug detail and MUST NOT be exposed
  in normal mode (P0 if it is).

---

## 1. Surfaces

Surface ids are stable and used as `ui_metric_surface` metadata.

| surface_id | dock/dialog | purpose |
|---|---|---|
| `timeline_dock` | dock | the predicted event/turn order projection (central surface) |
| `order_inspector` | dock/panel | why a given entry sits where it does (explanation of one row) |
| `config_panel` | dock/inspector | select + validate an `EQConfig`, bind its policy |
| `template_generator` | dialog | author a new config/policy from a template (sample-separated) |
| `calibration_tab` | hidden/dev | raw metric ledger + debug detail; never in normal mode |

Adding a surface follows UI_LAYOUT_METRIC_TEST_POLICY §7.2 (purpose → forbidden
debug → required state → required component → scroll → primary action → empty
state → Copy Debug Report boundary → scenarios → thresholds).

---

## 2. `timeline_dock`

**Purpose.** Show the predicted ordered output (event / turn / action order) for
the current config + injected snapshot, top = next to resolve.

**Required components** (`ui_metric_role`, `ui_metric_required=true`):

```text
screen_root      (Control)          — surface root
scroll_root      (ScrollContainer)  — vertical scroll owner for the list
summary          (section)          — count + freshness, icon-led
timeline_list    (Container)        — the rows
timeline_row     (Container) *N     — one per predicted entry
  order_index    (label, small)     — 1-based position; shown only when a prediction exists
  tick_badge     (badge)            — integer tick; width <= max_tick_badge_width
  actor_label    (label, expands)   — actor display name
  action_label   (label, expands)   — action/event label
  cause_icon     (status_icon?)     — optional: tie-break / reaction / reservation marker
empty_state      (empty_state)      — shown when no prediction / empty queue
status_icon      (status_icon)      — freshness (fresh vs stale) as icon, not text
primary_action   (button)           — `timeline.refresh_prediction`
debug_action     (button)           — `debug.copy_report` (single per surface)
```

Row layout (left→right): `[order_index][tick_badge][actor_label][action_label expands][cause_icon?]`.

**Forbidden visible text** (normal mode → P0/§5.5,§5.11):

```text
- float tick ("tick: 3.0") — ticks are integers; float ordering layer never surfaces
- /root/  @EditorNode  res://  user://  NodePath(  seq=  gen=  0x..  <Object#
- boolean state as text (stale shown as "stale: true" instead of a glyph/icon)
- raw event-id / EQEntry / EQSnapshot internals as a row's primary text
```

**Scroll policy.** `scroll_root` is a `ScrollContainer`; the list scrolls
vertically. **Horizontal scroll of the timeline list is a P0 failure** (§5.2) —
rows must fit width by eliding `action_label` (with tooltip), never by widening.
`primary_action` and `status_icon` stay outside the scrolled region (always reachable).

**Primary action.** `timeline.refresh_prediction` — rebuilds the prediction from
the current snapshot. Must have a pressed connection + effect beyond a status-label change.

**Empty state.** `empty_state` visible with an icon + short line when there is no
config / empty queue. When empty, `timeline_row` count is 0 and `order_index` is
not shown (showing an index without a prediction is a §5.2 WARN).

**Copy Debug Report boundary.** All debug detail (snapshot seq/gen, raw entries,
policy id, float ordering keys) goes into the `debug.copy_report` payload only —
never a visible label.

**Dead-area exception.** `timeline_list` is a declared result-waiting region; its
empty area does not count toward `dead_area_ratio` failure while `empty_state` is shown.

**Projection contract (central gate, §5.9).**

```text
ui_order       = [row entry id for each visible timeline_row, top→bottom]
headless_order = prediction(default_next_n_for_projection_test) from the injected snapshot
REQUIRE: ui_order == headless_order
REQUIRE: visible timeline_row count == min(N, len(headless_order))
tie (same tick): the rows MUST carry a cause_icon/tooltip distinguishing the tie-break
```

---

## 3. `order_inspector`

**Purpose.** Explain one selected entry: why it is at its position (decided_by /
tie-break / reaction / reservation), without re-deriving order text.

**Required components:**

```text
screen_root, scroll_root (if content can exceed height),
section (summary of the selected entry: actor icon + name + tick badge),
explanation_panel,
  explanation_row *N  — one factor per row (cause_icon + short phrase + optional tooltip)
empty_state          — "select an entry" when nothing is selected
debug_action         — debug.copy_report (single)
```

**Forbidden visible text.** Same debug set as §2. Explanation phrases are short;
long detail goes to tooltip (§5.1: titles short, detail to tooltip).

**Scroll policy.** If `explanation_row` count can exceed height, `scroll_root` is
a `ScrollContainer`. No horizontal scroll.

**Primary action.** None required (inspector is read-mostly). `debug.copy_report` only.

**Empty state.** `empty_state` when no row selected — not a blank panel
(`dead_area_ratio` would otherwise fail).

---

## 4. `config_panel`

**Purpose.** Pick an `EQConfig`, show validity, bind its policy.

**Required components:**

```text
screen_root,
config_slot   (resource_picker)  — base_type == "EQConfig" (NOT generic Resource)
policy_slot   (resource_picker)  — base_type == policy base (EQTurnPolicy/…); NOT base Resource
validation_list,
  validation_row *N  — status_icon (ok/warn/error) + short message; icon-led, not text-state
status_icon   (status_icon)      — overall validity as icon (ok/error), not "valid: true"
primary_action (button)          — `config.validate`
debug_action  (button)           — debug.copy_report (single)
```

**Forbidden visible text.** Debug set as §2; **boolean validity as text is P0**
(use ok/error icon). Filepath of the config shows only as a compact path chip,
not a raw `res://…` label (§5.5 WARN if leaked elsewhere).

**ResourcePicker specificity (§5.7, P0 on violation).**

```text
config_slot.base_type == "EQConfig"
policy_slot.base_type == policy base type (not "Resource")
any generic acceptance MUST be declared here + carry a backlog note
```

(No generic slot is currently permitted. If one is ever needed, declare it in §8.)

**Scroll policy.** `validation_list` scrolls vertically if it can exceed height;
no horizontal scroll.

**Primary action.** `config.validate` — runs `EQConfig.validate`, repopulates
`validation_list`. Must have effect beyond a status-label change.

**Empty state.** `no_config_selected` → `empty_state` visible, `validation_list`
empty, `status_icon` neutral (not "ok"). Contradiction (config==null but no
empty_state, or errors>0 but ok icon) is P0 (§5.8).

**min picker width.** `config_slot`/`policy_slot` width >= `min_picker_width_normal`
at normal, >= `min_picker_width_narrow` at narrow (§9).

---

## 5. `template_generator`

**Purpose.** Author a new config/policy from a built-in template; the sample
path is a *learning path*, separated from production.

**Required components:**

```text
screen_root, scroll_root (dialog body),
section (template choice: OptionButton, role=config_slot-adjacent),
summary (preview of what will be generated — icon-led),
primary_action   (button)  — `template.generate`
secondary_action (button)  — `template.duplicate_to_project` (the ONLY production bridge)
empty_state,
debug_action     (button)  — debug.copy_report (single)
```

**Sample separation (§5.10, P0 on violation).**

```text
- a generated sample/demo template MUST NOT satisfy a production required slot
  (config_panel.config_slot) without an explicit template.duplicate_to_project.
- sample_demo_loaded state MUST be visibly marked as sample (badge), never shown
  as a production config.
```

**Forbidden visible text.** Debug set as §2. A sample must be badged as sample,
not labeled with production-looking text.

**Primary action.** `template.generate` — produces the template artifact (in the
dialog's scratch space, not the project). `template.duplicate_to_project` is the
explicit, separate bridge to production.

**Scroll policy.** dialog body scrolls vertically; no horizontal scroll.

**Empty state.** `template_dialog_default` shows the default template selection +
preview (not blank).

---

## 6. `calibration_tab`

**Purpose.** Dev-only raw metric ledger / debug detail for threshold calibration
(`UI_LAYOUT_CALIBRATION_POLICY.md`). **Never exposed in normal mode** — exposure
in normal mode is a P0 failure (§6.1).

**Allowed content.** Raw numbers, float ordering keys, snapshot seq/gen, metric
ledger rows. This is the one surface exempt from the debug-leakage and
float-tick metrics, *conditioned on* it being hidden in normal mode.

**Required components.** `screen_root`, a `section` per metric family, and a
visible **dev-mode marker** so a snapshot can assert it is not normal mode.

---

## 7. Thresholds (M5-ratified)

Mirrors UI_LAYOUT_METRIC_TEST_POLICY §9 as the project's binding values. Calibration
updates these here (with a reason line) per `UI_LAYOUT_CALIBRATION_POLICY.md`.

**M5 status (EQM-095):** the P1 gate is active against these values. No calibration
ledger iteration has been baked yet (the loop is `manual-optional`, human-driven),
so the thresholds are **ratified at their initial values** — every real/good surface
passes P1 at them, so there is no evidence to move them. They change only when a real
tweak-and-bake session writes to `LAYOUT_CALIBRATION_LEDGER.md`; this is not a license
to hand-tune them without that evidence.

```text
min_picker_width_normal               = 180
min_picker_width_narrow               = 120
max_tick_badge_width                  = 64
min_actor_label_width_normal          = 80
max_row_icon_buttons                  = 1
max_debug_label_count_normal          = 0
max_dead_area_ratio_work_surface_warn = 0.60
max_dead_area_ratio_work_surface_fail = 0.75
max_visible_status_text_width_icon_mode = 48
default_next_n_for_projection_test    = 10
truncation_ratio_fail_normal          = 1.00   (required title / primary action)
truncation_ratio_warn_narrow          = 0.85
```

Acceptance dock sizes (UI_LAYOUT_METRIC_TEST_POLICY §4.1): narrow `320x600`,
normal `420x720`, wide `640x900`. UI scale matrix: `1.0, 1.25, 1.5`.

---

## 8. Declared exceptions

Generic ResourcePicker exceptions, allowed dead-area regions beyond the defaults,
and any text-only state allowances are listed here with a reason + backlog note.

| surface | exception | reason | backlog |
|---|---|---|---|
| timeline_dock | `timeline_list` dead area while `empty_state` shown | result-waiting region | — |
| order_inspector | `explanation_panel` dead area while `empty_state` shown | result-waiting region | — |
| config_panel | `validation_list` dead area while empty | result-waiting region | — |
| timeline_dock | `action_label` may elide (clip_text + EXPAND) at any width | the kind/action is secondary to order; full text is in tooltip; elide ≠ P1 because the label expands to fill, never starved | — |
| all | narrow-width (`320`) truncation is **WARN**, not P1 | narrow is the smallest acceptance dock; eliding there is acceptable; P1 truncation applies at normal+ (§6.2/§6.3) | — |

No generic ResourcePicker exceptions. No text-only state exceptions (all status
uses icon/checkbox/badge per `EDITOR_STATE_MATRIX.md`). The M5 P1 gate (EQM-095)
runs against these declarations: every real/good surface is P1-clean at normal width.

---

## 9. Action id registry

Visible enabled buttons MUST carry `ui_action_id` + `ui_action_effect` (§5.6).

| ui_action_id | surface | effect |
|---|---|---|
| `timeline.refresh_prediction` | timeline_dock | rebuild prediction from current snapshot |
| `config.validate` | config_panel | run EQConfig.validate, repopulate validation_list |
| `template.generate` | template_generator | produce template artifact in dialog scratch |
| `template.duplicate_to_project` | template_generator | explicit sample→production bridge |
| `debug.copy_report` | all | copy the surface's debug report to clipboard |

Any new visible enabled button MUST be added here before implementation.
