# Editor UI Contract

原文: `docs/ui/EDITOR_UI_CONTRACT.md`

Event Queue Manager editor UI の source-of-truth です。UI metric tests (`tests/ui_headless/*`, `tools/ui_static_audit.py`) は **このファイル** を基準に gate します。`docs/devflow/policy/UI_LAYOUT_METRIC_TEST_POLICY.md` は *formulas / severities* を定義し、このファイルは *project-specific values* (surfaces, required components, forbidden text, thresholds, dead-area exceptions) を保持します。state-dependent display は `EDITOR_STATE_MATRIX.md` にあります。

Adoption stage: **M5** (EQM-095)。metric harness は real/good surfaces に対して **P0 と P1** を build FAIL として enforce します。P0: no-op button, scroll reachability, state contradiction, debug leakage, float tick, projection integrity, sample separation。P1: row geometry, non-primary truncation, picker width, text-only status。static audit は `--enforce` で走ります。(Contract M0=EQM-086, harness M1-M3=EQM-087, first surfaces=EQM-090/091/092, P0 gate M4=EQM-093, calibration loop=EQM-094)。visible UI への変更は、まずこのファイルを更新しなければなりません (UI_LAYOUT_METRIC_TEST_POLICY §7.1)。

---

## 0. 原則 (binding)

- editor UI は **injected headless state の projection** です。第二の source of truth ではありません。timeline が表示する順序は同じ snapshot からの `prediction(N)` と一致しなければなりません (§5.9 projection integrity, central gate)。
- **state は non-text modality を最初に使って表示します** (icon / checkbox / badge / progress)。text は名前と tooltip 用であり、status 用ではありません。boolean state を text (`true/false`, `ON/OFF`, `有効/無効`) として出すことは P0 failure です (§5.11)。
- **normal mode で debug leakage を出しません。** debug detail は surface ごとの `Copy Debug Report` action からだけ到達できます (§5.5)。float tick は UI に出ません。
- **Sample ≠ production.** sample/demo template は明示的な `Duplicate To Project` step を通じてのみ production config に到達します。silent fallback は禁止です (§5.10)。
- **dev fail-fast / shipped fail-safe** は runtime concern です。editor はこれらの metric では常に dev-adjacent な "normal mode" で動きます。`calibration_tab` は raw numeric/debug detail を表示してよい唯一の surface であり、normal mode に露出してはいけません (露出したら P0)。

---

## 1. Surfaces

Surface id は stable で、`ui_metric_surface` metadata として使われます。

| surface_id | dock/dialog | purpose |
|---|---|---|
| `timeline_dock` | dock | predicted event/turn order projection (central surface) |
| `order_inspector` | dock/panel | ある entry がなぜその位置にいるか (1 row の explanation) |
| `config_panel` | dock/inspector | `EQConfig` を選択・validate し、policy を bind する |
| `template_generator` | dialog | template から新しい config/policy を author する (sample-separated) |
| `calibration_tab` | hidden/dev | raw metric ledger + debug detail。normal mode には出さない |

surface を追加するときは UI_LAYOUT_METRIC_TEST_POLICY §7.2 に従います (purpose → forbidden debug → required state → required component → scroll → primary action → empty state → Copy Debug Report boundary → scenarios → thresholds)。

---

## 2. `timeline_dock`

**目的。** current config + injected snapshot に対する predicted ordered output (event / turn / action order) を表示します。上が次に resolve される entry です。

**必須 components** (`ui_metric_role`, `ui_metric_required=true`):

```text
screen_root      (Control)          — surface root
scroll_root      (ScrollContainer)  — list の vertical scroll owner
summary          (section)          — count + freshness。icon-led
timeline_list    (Container)        — rows
timeline_row     (Container) *N     — predicted entry ごとに 1 row
  order_index    (label, small)     — 1-based position。prediction があるときだけ表示
  tick_badge     (badge)            — integer tick。width <= max_tick_badge_width
  actor_label    (label, expands)   — actor display name
  action_label   (label, expands)   — action/event label
  cause_icon     (status_icon?)     — optional: tie-break / reaction / reservation marker
empty_state      (empty_state)      — prediction がない / empty queue のとき表示
status_icon      (status_icon)      — freshness (fresh vs stale) を text ではなく icon で表示
primary_action   (button)           — `timeline.refresh_prediction`
debug_action     (button)           — `debug.copy_report` (surface ごとに 1 つ)
```

Row layout (left→right): `[order_index][tick_badge][actor_label][action_label expands][cause_icon?]`。

**禁止 visible text** (normal mode → P0/§5.5,§5.11):

```text
- float tick ("tick: 3.0") — tick は integer。float ordering layer は UI に出ない
- /root/  @EditorNode  res://  user://  NodePath(  seq=  gen=  0x..  <Object#
- boolean state as text (glyph/icon ではなく "stale: true" と出すなど)
- raw event-id / EQEntry / EQSnapshot internals を row の primary text にする
```

**Scroll policy。** `scroll_root` は `ScrollContainer` です。list は vertical scroll します。**timeline list の horizontal scroll は P0 failure** です (§5.2)。row は `action_label` を elide して幅に収めます (tooltip あり)。幅を広げてはいけません。`primary_action` と `status_icon` は scrolled region の外に置き、常に到達可能にします。

**Primary action。** `timeline.refresh_prediction` は current snapshot から prediction を rebuild します。pressed connection があり、status label の変更以上の effect を持つ必要があります。

**Empty state。** config / empty queue がないとき、`empty_state` は icon + short line とともに visible です。empty 時は `timeline_row` count は 0 で、`order_index` は表示しません (prediction なしで index を表示するのは §5.2 WARN)。

**Copy Debug Report boundary.** debug detail (snapshot seq/gen, raw entries, policy id, float ordering keys) は `debug.copy_report` payload にだけ入ります。visible label には出しません。

**Dead-area exception.** `timeline_list` は result-waiting region として宣言されています。`empty_state` 表示中、その empty area は `dead_area_ratio` failure に数えません。

**Projection contract (central gate, §5.9).**

```text
ui_order       = [visible timeline_row ごとの row entry id, top→bottom]
headless_order = injected snapshot からの prediction(default_next_n_for_projection_test)
REQUIRE: ui_order == headless_order
REQUIRE: visible timeline_row count == min(N, len(headless_order))
tie (same tick): rows は tie-break を区別する cause_icon/tooltip を持たなければならない
```

---

## 3. `order_inspector`

**目的。** selected entry がなぜその position にいるかを説明します (decided_by / tie-break / reaction / reservation)。order text を再導出しません。

**必須 components:**

```text
screen_root, scroll_root (content が height を超え得る場合),
section (selected entry の summary: actor icon + name + tick badge),
explanation_panel,
  explanation_row *N  — factor ごとに 1 row (cause_icon + short phrase + optional tooltip)
empty_state          — 何も選択されていないとき "select an entry"
debug_action         — debug.copy_report (single)
```

**禁止 visible text。** §2 と同じ debug set。explanation phrase は短くします。長い detail は tooltip に入れます (§5.1: titles short, detail to tooltip)。

**Scroll policy。** `explanation_row` count が height を超え得る場合、`scroll_root` は `ScrollContainer` です。horizontal scroll は禁止です。

**Primary action。** 必須ではありません (inspector は read-mostly)。`debug.copy_report` のみ。

**Empty state。** row 未選択時は `empty_state` を出します。blank panel にはしません (`dead_area_ratio` failure になるため)。

---

## 4. `config_panel`

**目的。** `EQConfig` を pick し、validity を表示し、policy を bind します。

**必須 components:**

```text
screen_root,
config_slot   (resource_picker)  — base_type == "EQConfig" (generic Resource ではない)
policy_slot   (resource_picker)  — base_type == policy base (EQTurnPolicy/…)。base Resource ではない
validation_list,
  validation_row *N  — status_icon (ok/warn/error) + short message。icon-led, not text-state
status_icon   (status_icon)      — overall validity を icon (ok/error) で表示。"valid: true" ではない
primary_action (button)          — `config.validate`
debug_action  (button)           — debug.copy_report (single)
```

**禁止 visible text。** §2 と同じ debug set。**boolean validity as text は P0** です (ok/error icon を使う)。config filepath は compact path chip としてだけ表示します。raw `res://…` label として漏らした場合は §5.5 WARN です。

**ResourcePicker specificity (§5.7, P0 on violation).**

```text
config_slot.base_type == "EQConfig"
policy_slot.base_type == policy base type (not "Resource")
any generic acceptance MUST be declared here + carry a backlog note
```

現在 generic slot は許可されていません。必要になった場合は §8 に宣言してください。

**Scroll policy。** `validation_list` が height を超え得る場合は vertical scroll します。horizontal scroll は禁止です。

**Primary action。** `config.validate` は `EQConfig.validate` を実行し、`validation_list` を再構築します。status label の変更以上の effect を持つ必要があります。

**Empty state。** `no_config_selected` → `empty_state` visible、`validation_list` empty、`status_icon` neutral ("ok" ではない)。矛盾 (config==null なのに empty_state がない、または errors>0 なのに ok icon) は P0 です (§5.8)。

**min picker width.** `config_slot` / `policy_slot` の width は normal で `min_picker_width_normal` 以上、narrow で `min_picker_width_narrow` 以上です (§9)。

---

## 5. `template_generator`

**目的。** built-in template から新しい config/policy を author します。sample path は *learning path* であり、production から分離されます。

**必須 components:**

```text
screen_root, scroll_root (dialog body),
section (template choice: OptionButton, role=config_slot-adjacent),
summary (生成内容の preview — icon-led),
primary_action   (button)  — `template.generate`
secondary_action (button)  — `template.duplicate_to_project` (唯一の production bridge)
empty_state,
debug_action     (button)  — debug.copy_report (single)
```

**Sample separation (§5.10, P0 on violation).**

```text
- generated sample/demo template は、明示的な template.duplicate_to_project なしに
  production required slot (config_panel.config_slot) を満たしてはいけない。
- sample_demo_loaded state は sample として visible mark (badge) を持つ必要があり、
  production config として表示してはいけない。
```

**禁止 visible text。** §2 と同じ debug set。sample は sample badge で示します。production に見える text label にはしません。

**Primary action。** `template.generate` は template artifact を生成します (dialog の scratch space、project ではない)。`template.duplicate_to_project` が production への明示的で別個の bridge です。

**Scroll policy。** dialog body は vertical scroll します。horizontal scroll は禁止です。

**Empty state。** `template_dialog_default` は default template selection + preview を表示します。blank にはしません。

---

## 6. `calibration_tab`

**目的。** threshold calibration 用の dev-only raw metric ledger / debug detail です (`UI_LAYOUT_CALIBRATION_POLICY.md`)。**normal mode には絶対に露出しません**。normal mode で露出した場合は P0 failure です (§6.1)。

**Allowed content.** raw numbers, float ordering keys, snapshot seq/gen, metric ledger rows。この surface だけが debug-leakage と float-tick metrics の exempt 対象です。ただし hidden in normal mode であることが条件です。

**必須 components。** `screen_root`、metric family ごとの `section`、snapshot が normal mode でないことを assert できる visible **dev-mode marker**。

---

## 7. Thresholds (M5-ratified)

UI_LAYOUT_METRIC_TEST_POLICY §9 を project の binding values として mirror します。Calibration は `UI_LAYOUT_CALIBRATION_POLICY.md` に従い、理由行とともにここを更新します。

**M5 status (EQM-095):** P1 gate はこれらの値に対して active です。calibration ledger iteration はまだ bake されていません (loop は `manual-optional`, human-driven)。そのため threshold は **initial values で ratified** されています。すべての real/good surface がこの値で P1 を pass しているため、動かす根拠はありません。threshold は real tweak-and-bake session が `LAYOUT_CALIBRATION_LEDGER.md` に記録された場合だけ変更します。証拠なしに hand-tune する許可ではありません。

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

Acceptance dock sizes (UI_LAYOUT_METRIC_TEST_POLICY §4.1): narrow `320x600`, normal `420x720`, wide `640x900`。UI scale matrix: `1.0, 1.25, 1.5`。

---

## 8. Declared exceptions

Generic ResourcePicker exceptions、default を超えて許可される dead-area regions、text-only state allowance は、理由 + backlog note とともにここに列挙します。

| surface | exception | reason | backlog |
|---|---|---|---|
| timeline_dock | `timeline_list` dead area while `empty_state` shown | result-waiting region | — |
| order_inspector | `explanation_panel` dead area while `empty_state` shown | result-waiting region | — |
| config_panel | `validation_list` dead area while empty | result-waiting region | — |
| timeline_dock | `action_label` may elide (clip_text + EXPAND) at any width | kind/action は order より副次的。full text は tooltip。label が expand して fill し、starved ではないため elide ≠ P1 | — |
| all | narrow-width (`320`) truncation is **WARN**, not P1 | narrow は最小 acceptance dock。そこでの elide は許容。P1 truncation は normal+ に適用 (§6.2/§6.3) | — |

Generic ResourcePicker exceptions はありません。text-only state exceptions もありません (status はすべて `EDITOR_STATE_MATRIX.md` に従い icon/checkbox/badge を使う)。M5 P1 gate (EQM-095) はこれらの declaration に対して走ります。すべての real/good surface は normal width で P1-clean です。

---

## 9. Action id registry

visible enabled button は `ui_action_id` + `ui_action_effect` を持たなければなりません (§5.6)。

| ui_action_id | surface | effect |
|---|---|---|
| `timeline.refresh_prediction` | timeline_dock | current snapshot から prediction を rebuild |
| `config.validate` | config_panel | EQConfig.validate を実行し、validation_list を再構築 |
| `template.generate` | template_generator | dialog scratch に template artifact を生成 |
| `template.duplicate_to_project` | template_generator | explicit sample→production bridge |
| `debug.copy_report` | all | surface の debug report を clipboard に copy |

新しい visible enabled button は、実装前に必ずここへ追加してください。
