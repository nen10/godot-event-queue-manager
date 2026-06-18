class_name EQDebugInspector
extends VBoxContainer
## Order inspector (EQM-091) — for a selected entry, explains why it sits where it
## does, rendered from EQOrderExplanation's structured data (explanation-as-data).
## The runtime never hands the UI a sentence; this surface maps factor keys to a
## short fixed label + icon + value, and marks the deciding factor.

const EQOrderExplanation := preload("res://addons/event_queue_manager/runtime/eq_order_explanation.gd")

const SURFACE := &"order_inspector"

## Fixed key -> short label / tooltip. UI presentation of structured keys, NOT
## free-form generated prose.
const KEY_LABEL := {
	&"due_tick": "tick",
	&"priority": "priority",
	&"sequence": "order",
}
const KEY_TOOLTIP := {
	&"due_tick": "earlier tick acts first",
	&"priority": "higher priority first",
	&"sequence": "earlier scheduled first (tie-break)",
}

var _section: Label
var _panel: VBoxContainer
var _empty: Label
var _decided_by: StringName = &""


func _init() -> void:
	set_meta(&"ui_metric_id", &"order_inspector_root")
	set_meta(&"ui_metric_role", &"screen_root")
	set_meta(&"ui_metric_surface", SURFACE)
	_section = Label.new()
	_section.set_meta(&"ui_metric_id", &"inspector_section")
	_section.set_meta(&"ui_metric_role", &"section")
	_section.set_meta(&"ui_metric_surface", SURFACE)
	add_child(_section)
	_panel = VBoxContainer.new()
	_panel.set_meta(&"ui_metric_id", &"inspector_panel")
	_panel.set_meta(&"ui_metric_role", &"explanation_panel")
	_panel.set_meta(&"ui_metric_surface", SURFACE)
	add_child(_panel)
	_empty = Label.new()
	_empty.text = "Select an entry"
	_empty.set_meta(&"ui_metric_id", &"inspector_empty_state")
	_empty.set_meta(&"ui_metric_role", &"empty_state")
	_empty.set_meta(&"ui_metric_surface", SURFACE)
	add_child(_empty)
	_apply_empty()


## Convenience: explain `entry` relative to its predecessor in the order.
func select(entry, predecessor = null) -> void:
	if entry == null:
		clear()
		return
	show_explanation(EQOrderExplanation.of(entry, predecessor))


func show_explanation(explanation: EQOrderExplanation) -> void:
	_clear_panel()
	if explanation == null:
		_apply_empty()
		return
	_empty.visible = false
	_panel.visible = true
	_section.visible = true
	_section.text = String(explanation.actor_id)
	_decided_by = explanation.decided_by
	for factor in explanation.factors:
		_panel.add_child(_make_factor_row(factor, factor["key"] == explanation.decided_by))


func clear() -> void:
	_clear_panel()
	_decided_by = &""
	_apply_empty()


## Roles rendered for the selected entry: one explanation_row per ordering factor.
func factor_rows() -> Array:
	var out: Array = []
	for c in _panel.get_children():
		if c.has_meta(&"ui_metric_role") and c.get_meta(&"ui_metric_role") == &"explanation_row":
			out.append(c)
	return out


func decided_by() -> StringName:
	return _decided_by


func is_empty_state() -> bool:
	return _empty.visible


func _apply_empty() -> void:
	_empty.visible = true
	_panel.visible = false
	_section.visible = false
	_section.text = ""


func _make_factor_row(factor: Dictionary, is_deciding: bool) -> Control:
	var key: StringName = factor["key"]
	var hb := HBoxContainer.new()
	hb.set_meta(&"ui_metric_id", StringName("inspector_factor_%s" % String(key)))
	hb.set_meta(&"ui_metric_role", &"explanation_row")
	hb.set_meta(&"ui_metric_surface", SURFACE)

	# cause icon (deciding factor is marked; both carry a tooltip)
	var icon := TextureRect.new()
	icon.texture = PlaceholderTexture2D.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.tooltip_text = String(KEY_TOOLTIP.get(key, key))
	icon.set_meta(&"ui_metric_role", &"cause_icon")
	icon.modulate = Color(1, 1, 1, 1) if is_deciding else Color(1, 1, 1, 0.5)
	if is_deciding:
		icon.set_meta(&"ui_decided", true)
	hb.add_child(icon)

	var label := Label.new()
	label.text = String(KEY_LABEL.get(key, key))
	label.custom_minimum_size = Vector2(64, 0)
	label.set_meta(&"ui_metric_role", &"explanation_key")
	hb.add_child(label)

	var value := Label.new()
	value.text = str(int(factor["value"]))  # integer — no float ordering leak
	value.set_meta(&"ui_metric_role", &"explanation_value")
	hb.add_child(value)
	return hb


func _clear_panel() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
