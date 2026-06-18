extends VBoxContainer
## Layout Calibration tab (EQM-094) — the tweak-and-bake debug surface
## (UI_LAYOUT_CALIBRATION_POLICY.md). DEBUG-ONLY: it appears only behind the
## EQ_EDITOR_CALIBRATION=1 flag and is invisible in normal mode (§6, P0). The user
## edits layout params per ui_metric_id live; "Copy Layout Feedback" emits a
## schema-valid JSON (§3) for the agent to bake. Edits are NEVER the source of
## truth — only baking persists them. Lives under editor/testing/ (dev tooling,
## excluded from the api-surface + static-audit scans).

const FEEDBACK_KIND := "eq_layout_feedback"
const FEEDBACK_VERSION := 1

## Editable params (§2 initial set) and how each maps onto a Control.
const EDITABLE_PARAMS := [
	"custom_minimum_size.x", "custom_minimum_size.y",
	"size_flags_horizontal", "size_flags_vertical", "font_size",
]

var _enabled: bool = false
var _surface_id: StringName = &""
var _controls: Dictionary = {}     # ui_metric_id -> Control
var _edited: Array = []            # [{id, param, old, new}]
var _touched_ids: Dictionary = {}  # ui_metric_id -> true


## Reads the debug flag unless `force_enabled` overrides it (tests inject true).
static func flag_enabled() -> bool:
	return OS.get_environment("EQ_EDITOR_CALIBRATION") == "1"


func _init(force_enabled = null) -> void:
	_enabled = bool(force_enabled) if force_enabled != null else flag_enabled()
	set_meta(&"ui_metric_id", &"calibration_tab")
	set_meta(&"ui_metric_role", &"calibration_tab")
	set_meta(&"ui_metric_surface", &"calibration_tab")
	# Invisible in normal mode (no flag). This is the §6 P0 guarantee — a hidden
	# Control is skipped by the metric collector entirely, so it can never leak.
	visible = _enabled
	if _enabled:
		_build_controls()


func is_enabled() -> bool:
	return _enabled


func _build_controls() -> void:
	var copy_btn := Button.new()
	copy_btn.text = "Copy Layout Feedback"
	copy_btn.set_meta(&"ui_metric_role", &"primary_action")
	copy_btn.set_meta(&"ui_action_id", &"calibration.copy_feedback")
	copy_btn.set_meta(&"ui_action_effect", "emit schema-valid layout feedback JSON to the clipboard")
	copy_btn.pressed.connect(func(): _copy_to_clipboard())
	add_child(copy_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Surface"
	reset_btn.set_meta(&"ui_metric_role", &"secondary_action")
	reset_btn.set_meta(&"ui_action_id", &"calibration.reset_surface")
	reset_btn.set_meta(&"ui_action_effect", "revert all live edits on this surface")
	reset_btn.pressed.connect(func(): reset_surface())
	add_child(reset_btn)


## Register the surface being calibrated and its ui_metric_id-bearing controls.
func set_target(surface_id: StringName, controls: Array) -> void:
	_surface_id = surface_id
	_controls.clear()
	for c in controls:
		if c is Control and c.has_meta(&"ui_metric_id"):
			_controls[c.get_meta(&"ui_metric_id")] = c


## Editable param ids for a control (only those that apply to its class).
func editable_params(ui_metric_id: StringName) -> Array:
	if not _controls.has(ui_metric_id):
		return []
	var out: Array = []
	for p in EDITABLE_PARAMS:
		if p == "font_size" and not (_controls[ui_metric_id] is Label or _controls[ui_metric_id] is Button):
			continue
		out.append(p)
	return out


## Apply a param edit live to the target control and record it (old + new).
func edit(ui_metric_id: StringName, param: String, value) -> bool:
	if not _controls.has(ui_metric_id) or not EDITABLE_PARAMS.has(param):
		return false
	var c: Control = _controls[ui_metric_id]
	var old = _read_param(c, param)
	if not _write_param(c, param, value):
		return false
	_edited.append({"id": String(ui_metric_id), "param": param, "old": old, "new": value})
	_touched_ids[ui_metric_id] = true
	return true


func reset_surface() -> void:
	for entry in _edited:
		var id := StringName(entry["id"])
		if _controls.has(id):
			_write_param(_controls[id], entry["param"], entry["old"])
	_edited.clear()
	_touched_ids.clear()


## The §3 feedback document — layout params only, no file/node/project info.
func layout_feedback(scenario: String, dock_size: Vector2, ui_scale: float, note: String = "") -> Dictionary:
	var untouched: Array = []
	for id in _controls.keys():
		if not _touched_ids.has(id):
			untouched.append(String(id))
	untouched.sort()
	return {
		"kind": FEEDBACK_KIND,
		"version": FEEDBACK_VERSION,
		"surface": String(_surface_id),
		"scenario": scenario,
		"dock_size": [dock_size.x, dock_size.y],
		"ui_scale": ui_scale,
		"edited": _edited.duplicate(true),
		"untouched": untouched,
		"note": note,
		"timestamp": Time.get_datetime_string_from_system(),
	}


func layout_feedback_json(scenario: String, dock_size: Vector2, ui_scale: float, note: String = "") -> String:
	return JSON.stringify(layout_feedback(scenario, dock_size, ui_scale, note), "  ")


func _copy_to_clipboard() -> void:
	# context (scenario/dock/scale) is supplied by the host dock in the editor;
	# here we emit with neutral context so the button has a real effect.
	DisplayServer.clipboard_set(layout_feedback_json("", get_viewport_rect().size, 1.0))


func _read_param(c: Control, param: String):
	match param:
		"custom_minimum_size.x": return c.custom_minimum_size.x
		"custom_minimum_size.y": return c.custom_minimum_size.y
		"size_flags_horizontal": return c.size_flags_horizontal
		"size_flags_vertical": return c.size_flags_vertical
		"font_size": return c.get_theme_font_size(&"font_size") if c.has_method(&"get_theme_font_size") else 0
	return null


func _write_param(c: Control, param: String, value) -> bool:
	match param:
		"custom_minimum_size.x":
			c.custom_minimum_size = Vector2(float(value), c.custom_minimum_size.y)
		"custom_minimum_size.y":
			c.custom_minimum_size = Vector2(c.custom_minimum_size.x, float(value))
		"size_flags_horizontal":
			c.size_flags_horizontal = int(value)
		"size_flags_vertical":
			c.size_flags_vertical = int(value)
		"font_size":
			c.add_theme_font_size_override(&"font_size", int(value))
		_:
			return false
	return true
