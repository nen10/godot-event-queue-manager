# UI Layout Metric Test Policy

対象: Event Queue Manager editor UI (timeline_dock, order_inspector, config_panel, template_generator)
目的: Godot Control tree のサイズ・状態・情報量・操作契約を数値評価し、UI 改修の acceptance gate として使う。

上位方針: `docs/devflow/policy/UI_TESTABILITY_POLICY.md` (layer L0-L3)
基準値の置き場: `docs/ui/EDITOR_UI_CONTRACT.md` / `docs/ui/EDITOR_STATE_MATRIX.md`

---

## 0. 結論

UI の見た目を人間が確認する前に、多くの欠陥は **Control tree の数値評価** で検出できる。

```text
UI tree
  -> layout snapshot JSON
    -> metric evaluator
      -> fail / warn / info report
        -> acceptance decision
```

評価の考え方:

```text
- UIを見た感想ではなく、UI構造の破綻可能性を数値で検出する。
- headless test の都合で UI を歪めない。Godot 自身を layout oracle として使う。
- 美しさは判定しない。
- label切れ、scroll不能、no-op button、debug漏れ、状態矛盾、表示順序不一致は機械判定する。
```

## 1. 適用範囲

### 1.1 対象 Control 種別

```text
Control / Container 系 (VBox/HBox/Grid/Margin)
ScrollContainer / SplitContainer
Label / Button / CheckBox / OptionButton
EditorResourcePicker
Tree / ItemList / LineEdit / ProgressBar
custom controls under addons/event_queue_manager/editor/
```

### 1.2 非対象 (analog / calibration 行き)

色彩、余白の美的評価、日本語表現の自然さ、安心感。

ただし以下は数値評価対象である:

```text
- label が割当幅を超える
- debug 文字列の通常 UI 露出
- 重要 action が scroll なしで到達できない
- generic Resource picker
- state が label text によって表示される, checkboxや文字なしで意味のわかるicon等を使用していない
- UI 表示順序と headless 計算順序の不一致
```

## 2. Test architecture

### 2.1 Required files

```text
addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd
addons/event_queue_manager/editor/testing/eq_ui_layout_metric_evaluator.gd
addons/event_queue_manager/editor/testing/eq_ui_state_scenario_builder.gd

tests/ui_headless/test_editor_layout_metrics.gd
tests/ui_headless/test_editor_state_matrix.gd
tests/ui_headless/test_editor_interaction_contract.gd

tools/ui_static_audit.py
```

`editor/testing/` を配布 package に含めるかは package task (EQM-103) で判断する。

### 2.2 Two-pass testing

```text
Pass A: Godot headless layout pass
  実 Control tree を構築し、layout 後の rect を読む。

Pass B: Static audit pass
  GDScript source の危険 pattern を python で検出する。
```

Godot の Container layout を Python で再実装しない。**Godot 自身を layout oracle として使う**。Static audit は高速な補助であり、Pass A の代替ではない。

## 3. Snapshot model

### 3.1 Node snapshot fields

visible Control ごとに最低限以下を収集する:

```text
id, name, class, script_class, visible, disabled,
surface_id, semantic_role,
rect, global_rect, minimum_size, combined_minimum_size, custom_minimum_size,
size_flags_horizontal / vertical,
text, text_width, allocated_text_width,
tooltip, tooltip_length,
button_pressed_connections, action_id, action_effect,
resource_picker_base_type, resource_picker_has_resource,
is_scroll_container, inside_scroll_container,
visible_text_kind (user / status / debug / internal / filepath / nodepath)
```

### 3.2 Stable IDs / roles

`node_path` は実行ごとに変わり得るため評価 ID に使わない。重要 Control は metadata を持つ:

```gdscript
control.set_meta("ui_metric_id", "timeline.row.actor_label")
control.set_meta("ui_metric_role", "actor_label")
control.set_meta("ui_metric_surface", "timeline_dock")
control.set_meta("ui_metric_required", true)
```

最低限の role:

```text
screen_root, scroll_root, section, summary, empty_state,
timeline_list, timeline_row, order_index, tick_badge, actor_label, action_label, cause_icon,
explanation_panel, explanation_row,
config_slot, policy_slot, resource_picker, validation_list, validation_row,
status_icon, status_text,
primary_action, secondary_action, debug_action, progress, busy_state
```

metadata がない場合 collector は class/name/text から推定するが、重要 UI では metadata を必須とする。

## 4. Scenario matrix

### 4.1 Dock sizes

```text
width:  280, 320, 360, 420, 520, 640
height: 420, 600, 720, 900
```

acceptance 標準:

```text
narrow: 320x600
normal: 420x720
wide:   640x900
```

### 4.2 UI scale

```text
scale: 1.0, 1.25, 1.5
```

font size matrix での疑似再現でよい。

### 4.3 Text variants

```text
en_short / ja_short / ja_long / long_actor_names / long_action_names
```

例:

```text
Slime
とてもながいなまえのまほうつかい
Prepared Strike of the Seventeen Winters
準備攻撃（広範囲・解決時間3・反芻1）
```

### 4.4 Editor states

最低限 (確定値は EDITOR_STATE_MATRIX.md):

```text
no_config_selected
invalid_config_missing_policy
valid_config_no_actors
small_queue_3_actors
tie_break_same_tick
large_queue_500_entries
prediction_fresh
prediction_stale
transaction_draft_active
reaction_armed_visible
template_dialog_default
sample_demo_loaded
```

## 5. Metric definitions

### 5.1 Text truncation risk

```text
text_width = font.get_string_size(text).x
allocated_text_width = control.rect.size.x - horizontal_content_padding
truncation_ratio = text_width / max(allocated_text_width, 1)

FAIL:
- required title / primary action の truncation_ratio > 1.00 at normal width
WARN:
- 非 critical label の truncation_ratio > 1.00
- 任意 text の truncation_ratio > 0.85 at narrow width
```

title は短くし、説明は tooltip へ移す。

### 5.2 Timeline row geometry

期待 row 構造:

```text
[order_index] [tick_badge] [actor_label] [action_label expands] [cause_icon?]
```

```text
FAIL:
- tick_badge_width > 64 at normal width
- actor_label_width < 80 at normal width
- 同一 list 内で row_height が不均一
- timeline list に horizontal scroll が必要
- row 内 icon-button > 1
WARN:
- action_label truncation at normal width で tooltip なし
- prediction が無いのに order_index が表示される
```

### 5.3 Scroll reachability

```text
requires_scroll = content_height > viewport_height
has_scroll = surface root is ScrollContainer or child scroll covers primary content

FAIL:
- requires_scroll and not has_scroll
- required primary action が viewport 外かつ ScrollContainer 外
WARN:
- 初期 state で primary action が first viewport より下
```

### 5.4 Dead area / control density

```text
dead_area_ratio = 1.0 - occupied_area / max(visible_area, 1)

FAIL: dead_area_ratio > 0.75 (preview/list/table の宣言なし)
WARN: dead_area_ratio > 0.60
```

例外 (timeline list, validation list 等の結果待ち領域) は EDITOR_UI_CONTRACT.md に宣言する。

### 5.5 Visible debug leakage

EQM debug patterns:

```text
/root/   @EditorNode   res://   user://   NodePath(
true / false (state label として)
EQEntry   EQSnapshot   seq=   gen=   0x[0-9a-f]+   <Object#
Invalid call   Nonexistent function
float 表記の tick (例: "tick: 3.0")
```

```text
FAIL:
- normal mode の debug_label_count > 0
- tick の float 形式表示 (float time が UI まで漏れた証拠)
WARN:
- filepath が compact path chip / debug section 外に露出
```

debug 詳細は surface ごと最大 1 個の `Copy Debug Report` button に集約する。

### 5.6 No-op button audit

visible button は metadata を持つ:

```gdscript
button.set_meta("ui_action_id", "timeline.refresh_prediction")
button.set_meta("ui_action_effect", "rebuilds prediction from current snapshot")
```

action id 例: `timeline.refresh_prediction`, `config.validate`, `template.generate`, `debug.copy_report`。

```text
FAIL:
- visible enabled button に pressed connection がない
- visible enabled button に ui_action_id がない
- button の効果が status label 変更のみ
- ResourcePicker 標準動作 (clear/load) の重複 button
WARN:
- disabled button に条件説明 tooltip がない
```

### 5.7 ResourcePicker type specificity

```text
FAIL:
- config slot の base_type != "EQConfig"
- policy slot が base Resource を受け入れる
- 必須 slot の required_type と base_type の不一致
```

generic 許容は EDITOR_UI_CONTRACT.md への記載 + backlog note を必須とする。

### 5.8 State contradiction

EQM examples:

```text
config != null なのに "No config selected"
validation errors > 0 なのに OK badge 表示
prediction_stale == true なのに stale indicator 非表示
queue が空なのに timeline rows > 0
draft_active == true なのに commit/rollback が条件記載なく disabled
sample template を production config として表示
```

```text
FAIL: normal mode のあらゆる state contradiction
```

state contradiction test は screenshot より重要である。

### 5.9 Projection integrity (EQM 固有)

```text
ui_order       = [row.event_id for visible timeline_row]
headless_order = prediction(N) from injected snapshot

FAIL:
- ui_order != headless_order
- visible row count != min(N, len(headless_order))
WARN:
- 同 tick 行 (tie-break) に indicator / tooltip がない
```

表示順序が信頼できない timeline は負価値である。この metric は本 addon の中心 gate とする。

### 5.10 Sample separation

```text
FAIL:
- sample/demo template が production 導線へ silent 進入する
- sample resource が明示操作なしに production required slot を満たす
```

sample は learning path であり、`Duplicate To Project` 相当の明示経路のみ production へ繋がる。

### 5.11 State display modality

state の表示は文字列ではなく、文字なしで意味が伝わる modality (status icon / checkbox / badge / progress) を優先する。説明は tooltip へ置く。

```text
state_text_labels = count(status role の Control で、icon/checkbox を持たず text のみで状態を表すもの)
boolean_text_labels = count(boolean state を "true/false", "ON/OFF", "有効/無効" 等の文字列で表示するもの)

FAIL:
- boolean_text_labels > 0 (normal mode)
P1_FAIL:
- required surface で state_text_labels > 0 (icon/checkbox 代替が定義可能なのに text 表示)
WARN:
- status text width > max_visible_status_text_width_icon_mode
- icon のみで tooltip がない (icon + tooltip を要求)
```

`EDITOR_STATE_MATRIX.md` は各 state について期待 modality (icon id / checkbox / badge) を記載する。text 表示を許す state は理由つきで契約に宣言する。

## 6. Acceptance severity

### 6.1 P0_FAIL (常に accept 不可)

```text
- visible enabled no-op button
- 必須 content の scroll 不能
- state contradiction (normal mode)
- debug leakage (normal mode)
- float tick display
- projection integrity violation
- production 必須 picker の generic Resource
- sample silent fallback
- calibration tab の normal mode 露出
- boolean state の text label 表示 (true/false 等)
```

### 6.2 P1_FAIL

```text
- 非 primary text の truncation at normal width
- row 内 icon-button 過多
- dead area 超過 (例外宣言なし)
- disabled action の tooltip 欠落
- optional generic slot の backlog note 欠落
- required surface での state の text-only 表示 (icon/checkbox 代替未使用)
```

### 6.3 WARN

```text
- narrow 幅のみの truncation risk
- scroll で到達可能だが初期 viewport 外の primary action
- 高 text 密度、tooltip 過長、surface 間の文言不統一
```

## 7. Procedures

### 7.1 UI component の追加・変更

```text
1. EDITOR_UI_CONTRACT.md を更新 (visible UI が変わる場合)。
2. EDITOR_STATE_MATRIX.md を更新 (表示が state 依存の場合)。
3. 新 Control に ui_metric_id / role / surface metadata を付与。
4. 実装。
5. layout metric test / interaction contract test を更新。
6. tools/ui_static_audit.py を実行。
7. ./tools/test.sh を実行 (Godot があれば)。
8. self-review に metric report path を記載。
```

### 7.2 新 surface の追加

目的、禁止 debug 情報、必須 state、必須 component、scroll 方針、primary action、empty state、Copy Debug Report 境界、scenario 追加、threshold 追加、の順で定義してから実装する。

### 7.3 Button の追加

primary / secondary / context_menu / debug / remove に分類し、§5.6 の checklist を満たす。

### 7.4 Debug 情報の露出

visible debug Label を追加しない。debug report model に field を追加し、Copy Debug Report に含め、leakage test が通ることを確認する。compact 表示が必要なら icon + tooltip。

## 8. Report format

```text
.godot_user/test-runs/<run-id>/ui_metrics.json
.godot_user/test-runs/<run-id>/ui_metrics.md
```

```md
# Editor UI Metrics Report

Run: <id> / Godot: <version> / Date: <date>

## Summary
- P0 failures: 0
- P1 failures: 1
- Warnings: n

## P1 failures
### timeline_dock / small_queue_3_actors / 320x600
timeline.row.actor_label width=64 < 80.
Suggested fix: ...
```

self-review は report path を引用する。

## 9. 初期 threshold (校正前)

```text
min_picker_width_normal = 180
min_picker_width_narrow = 120
max_tick_badge_width = 64
min_actor_label_width_normal = 80
max_row_icon_buttons = 1
max_debug_label_count_normal = 0
max_dead_area_ratio_work_surface = 0.65 warn / 0.75 fail
max_visible_status_text_width_icon_mode = 48
default_next_n_for_projection_test = 10
```

校正は UI_LAYOUT_CALIBRATION_POLICY.md の ledger 実績で更新し、変更理由を EDITOR_UI_CONTRACT.md に残す。

## 10. Adoption

UI_TESTABILITY_POLICY.md §6 の M0-M5 に従う (EQM-086 / EQM-087 / EQM-093 / EQM-094 / EQM-095)。
