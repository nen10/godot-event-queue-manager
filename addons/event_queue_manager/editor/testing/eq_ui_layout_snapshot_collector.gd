extends RefCounted
## Pass A snapshot collector (UI_LAYOUT_METRIC_TEST_POLICY §3).
##
## Walks a laid-out Control tree and emits one Dictionary per *visible* Control
## with the §3.1 fields. Godot itself is the layout oracle: the caller must add
## the tree to a viewport at the scenario dock size and flush layout (await two
## process_frames) BEFORE collecting — rects are read, never recomputed.
##
## Stable ids/roles come from ui_metric_* metadata (set by the surface); when a
## control lacks metadata the collector infers class/role/text-kind heuristically
## (policy §3.2: metadata required on important controls, inferred otherwise).

const META_ID := &"ui_metric_id"
const META_ROLE := &"ui_metric_role"
const META_SURFACE := &"ui_metric_surface"
const META_REQUIRED := &"ui_metric_required"
const META_ACTION_ID := &"ui_action_id"
const META_ACTION_EFFECT := &"ui_action_effect"


## Collect a snapshot for one scenario. `dock_size` is the viewport size the tree
## was laid out at (recorded for threshold selection narrow/normal/wide).
static func collect(root: Control, surface_id: StringName, dock_size: Vector2) -> Dictionary:
	var nodes: Array = []
	_walk(root, surface_id, false, nodes)
	return {
		"surface": String(surface_id),
		"dock_size": [dock_size.x, dock_size.y],
		"nodes": nodes,
	}


static func _walk(node: Node, surface_id: StringName, inside_scroll: bool, out: Array) -> void:
	var c := node as Control
	var child_inside_scroll := inside_scroll
	if c != null:
		if not c.visible:
			return  # invisible subtrees are not part of the projection
		out.append(_node_snapshot(c, surface_id, inside_scroll))
		if c is ScrollContainer:
			child_inside_scroll = true
	for child in node.get_children():
		_walk(child, surface_id, child_inside_scroll, out)


static func _node_snapshot(c: Control, surface_id: StringName, inside_scroll: bool) -> Dictionary:
	var text := _text_of(c)
	var font := _font_of(c)
	var font_size := _font_size_of(c)
	var text_width := 0.0
	if text != "" and font != null:
		text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var rect := c.get_rect()
	var grect := c.get_global_rect()
	var allocated_text_width: float = maxf(rect.size.x - _h_padding(c), 1.0)
	var role := _role_of(c)
	return {
		"id": _id_of(c),
		"name": String(c.name),
		"class": c.get_class(),
		"script_class": _script_class_of(c),
		"visible": c.visible,
		"disabled": _disabled_of(c),
		"surface": String(c.get_meta(META_SURFACE, surface_id)),
		"role": String(role),
		"required": bool(c.get_meta(META_REQUIRED, false)),
		"entry_id": String(c.get_meta(&"ui_entry_id", "")),
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"global_rect": [grect.position.x, grect.position.y, grect.size.x, grect.size.y],
		"minimum_size": [c.get_minimum_size().x, c.get_minimum_size().y],
		"combined_minimum_size": [c.get_combined_minimum_size().x, c.get_combined_minimum_size().y],
		"custom_minimum_size": [c.custom_minimum_size.x, c.custom_minimum_size.y],
		"size_flags_h": c.size_flags_horizontal,
		"size_flags_v": c.size_flags_vertical,
		"text": text,
		"text_width": text_width,
		"allocated_text_width": allocated_text_width,
		"truncation_ratio": text_width / allocated_text_width,
		"tooltip": c.tooltip_text,
		"tooltip_length": c.tooltip_text.length(),
		"has_pressed_connection": _has_pressed_connection(c),
		"action_id": String(c.get_meta(META_ACTION_ID, "")),
		"action_effect": String(c.get_meta(META_ACTION_EFFECT, "")),
		"resource_picker_base_type": _picker_base_type(c),
		"resource_picker_has_resource": _picker_has_resource(c),
		"is_scroll_container": c is ScrollContainer,
		"inside_scroll_container": inside_scroll,
		"is_button_like": _is_button_like(c),
		"is_icon_button": _is_icon_button(c),
		"has_status_glyph": _has_status_glyph(c),
		"visible_text_kind": _visible_text_kind(c, text, role),
	}


static func _id_of(c: Control) -> String:
	if c.has_meta(META_ID):
		return String(c.get_meta(META_ID))
	return String(c.name)


static func _role_of(c: Control) -> StringName:
	if c.has_meta(META_ROLE):
		return c.get_meta(META_ROLE)
	# inference fallback (policy §3.2)
	if c is ScrollContainer:
		return &"scroll_root"
	if _is_button_like(c):
		return &"action"
	if c is Label:
		return &"label"
	return &"control"


static func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is LineEdit:
		return (c as LineEdit).text
	return ""


static func _font_of(c: Control) -> Font:
	if c.has_method(&"get_theme_font"):
		var f: Font = c.get_theme_font(&"font")
		if f != null:
			return f
	return ThemeDB.fallback_font


static func _font_size_of(c: Control) -> int:
	if c.has_method(&"get_theme_font_size"):
		var s: int = c.get_theme_font_size(&"font_size")
		if s > 0:
			return s
	return ThemeDB.fallback_font_size


static func _h_padding(c: Control) -> float:
	# Allocated text box = rect minus content padding. A Button's minimum size
	# already includes its theme content margins, so a min-sized button always
	# fits its label; subtracting more would forge truncation. Use 0 so only a
	# genuinely width-constrained control (rect < text) reads ratio > 1.
	return 0.0


static func _disabled_of(c: Control) -> bool:
	if c is BaseButton:
		return (c as BaseButton).disabled
	return false


static func _script_class_of(c: Control) -> String:
	var s: Script = c.get_script()
	if s != null and s is GDScript:
		var n: String = (s as GDScript).get_global_name()
		if n != "":
			return n
	return ""


static func _has_pressed_connection(c: Control) -> bool:
	if c is BaseButton:
		return (c as BaseButton).pressed.get_connections().size() > 0
	return false


static func _is_button_like(c: Control) -> bool:
	return c is BaseButton


static func _is_icon_button(c: Control) -> bool:
	if c is Button:
		var b := c as Button
		return b.icon != null and b.text == ""
	return false


static func _has_status_glyph(c: Control) -> bool:
	# a status indicator carried by icon/checkbox rather than text
	if c is TextureRect:
		return (c as TextureRect).texture != null
	if c is CheckBox or c is CheckButton:
		return true
	if c is Button:
		return (c as Button).icon != null
	if c is ProgressBar:
		return true
	# an icon glyph hinted by metadata role
	var role := _role_of(c)
	return role in [&"status_icon", &"cause_icon", &"stale_indicator", &"position_badge"]


static func _picker_base_type(c: Control) -> String:
	# EditorResourcePicker is editor-only; read base_type when present, else "".
	if c.has_method(&"get_base_type"):
		return String(c.call(&"get_base_type"))
	if c.has_meta(&"ui_picker_base_type"):
		return String(c.get_meta(&"ui_picker_base_type"))
	return ""


static func _picker_has_resource(c: Control) -> bool:
	if c.has_method(&"get_edited_resource"):
		return c.call(&"get_edited_resource") != null
	if c.has_meta(&"ui_picker_has_resource"):
		return bool(c.get_meta(&"ui_picker_has_resource"))
	return false


static func _visible_text_kind(c: Control, text: String, role: StringName) -> String:
	if text == "":
		return "none"
	if c.has_meta(&"ui_text_kind"):
		return String(c.get_meta(&"ui_text_kind"))
	# pattern inference (policy §5.5 debug set)
	for pat in ["/root/", "@EditorNode", "res://", "user://", "NodePath(", "seq=", "gen=", "<Object#", "EQEntry", "EQSnapshot"]:
		if text.find(pat) != -1:
			return "debug"
	if role in [&"status_icon", &"status_text", &"stale_indicator"]:
		return "status"
	return "user"
