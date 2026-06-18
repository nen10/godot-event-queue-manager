extends RefCounted
## Builds synthetic Control trees for the editor scenario states
## (docs/ui/EDITOR_STATE_MATRIX.md). At M1-M3 these are SYNTHETIC trees that
## exercise the collector + evaluator before the real docks exist (EQM-090+);
## later phases feed real surfaces through the same collector.
##
## Two families:
##   good_*   — well-formed; the evaluator must find ZERO P0.
##   broken_* — one deliberate defect; the evaluator MUST raise the matching P0.
## The broken family is the non-tautology proof (DETERMINISM_TRACE_TEST_POLICY §3
## spirit: a metric that cannot fail is worthless).


## Scenario descriptors consumed by the runner.
static func scenarios() -> Array:
	return [
		# good
		{"name": "good_small_queue_3_actors", "surface": "timeline_dock", "kind": "good",
			"headless_order": ["hero", "orc", "goblin"], "next_n": 10},
		{"name": "good_large_queue_windowed", "surface": "timeline_dock", "kind": "good",
			"headless_order": _seq(500), "next_n": 10},
		{"name": "good_tie_break_same_tick", "surface": "timeline_dock", "kind": "good",
			"headless_order": ["a", "b", "c"], "next_n": 10},
		{"name": "good_no_config_selected", "surface": "config_panel", "kind": "good"},
		# broken (each maps to one metric the evaluator must flag)
		{"name": "broken_truncation_title", "surface": "timeline_dock", "kind": "broken",
			"metric": "truncation"},
		{"name": "broken_noop_button", "surface": "timeline_dock", "kind": "broken",
			"metric": "noop_button"},
		{"name": "broken_projection_misorder", "surface": "timeline_dock", "kind": "broken",
			"metric": "projection_integrity", "headless_order": ["a", "b", "c"], "next_n": 10},
		{"name": "broken_boolean_text_state", "surface": "config_panel", "kind": "broken",
			"metric": "modality"},
		{"name": "broken_debug_leak", "surface": "timeline_dock", "kind": "broken",
			"metric": "debug_leakage"},
		{"name": "broken_float_tick", "surface": "timeline_dock", "kind": "broken",
			"metric": "debug_leakage"},
	]


static func build(name: String, dock_size: Vector2) -> Control:
	match name:
		"good_small_queue_3_actors":
			return _timeline(["hero", "orc", "goblin"], [3, 5, 7], dock_size, {})
		"good_large_queue_windowed":
			# 500 predicted, but only the first 10 are rendered (windowing)
			var ids: Array = _seq(10)
			var ticks: Array = []
			for i in 10:
				ticks.append(i + 1)
			return _timeline(ids, ticks, dock_size, {"count": 500})
		"good_tie_break_same_tick":
			return _timeline(["a", "b", "c"], [4, 4, 6], dock_size, {"tie_rows": [0, 1]})
		"good_no_config_selected":
			return _config_panel_empty(dock_size)
		"broken_truncation_title":
			return _timeline(["hero"], [3], dock_size, {"broken_title": true})
		"broken_noop_button":
			return _timeline(["hero"], [3], dock_size, {"broken_noop": true})
		"broken_projection_misorder":
			# rows added in reverse of headless order -> ui_order != prediction
			return _timeline(["c", "b", "a"], [6, 4, 3], dock_size, {})
		"broken_boolean_text_state":
			return _config_panel_empty(dock_size, {"boolean_text": true})
		"broken_debug_leak":
			return _timeline(["hero"], [3], dock_size, {"debug_leak": true})
		"broken_float_tick":
			return _timeline(["hero"], [3], dock_size, {"float_tick": true})
	return Control.new()


static func _seq(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append("e%03d" % i)
	return out


# --- timeline_dock synthetic tree -----------------------------------------
static func _timeline(ids: Array, ticks: Array, dock_size: Vector2, opts: Dictionary) -> Control:
	var root := _root(dock_size, &"timeline_dock")
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(vb)

	# summary (count + freshness icon)
	var summary := HBoxContainer.new()
	summary.set_meta(&"ui_metric_role", &"summary")
	summary.set_meta(&"ui_metric_surface", &"timeline_dock")
	var count_badge := Label.new()
	count_badge.text = str(opts.get("count", ids.size()))
	count_badge.set_meta(&"ui_metric_role", &"badge_count")
	summary.add_child(count_badge)
	var status_icon := _status_glyph(&"status_icon", "prediction fresh")
	summary.add_child(status_icon)
	vb.add_child(summary)

	# optional broken title (required, clipped, starved of width)
	if opts.get("broken_title", false):
		vb.add_child(_starved_title("Prepared Strike of the Seventeen Winters Extended Edition Title"))

	# rows
	var list := VBoxContainer.new()
	list.set_meta(&"ui_metric_role", &"timeline_list")
	list.set_meta(&"ui_metric_surface", &"timeline_dock")
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in ids.size():
		var tie_rows: Array = opts.get("tie_rows", [])
		var float_tick: bool = opts.get("float_tick", false) and i == 0
		var debug_leak: bool = opts.get("debug_leak", false) and i == 0
		list.add_child(_row(i, ids[i], ticks[i], tie_rows.has(i), float_tick, debug_leak))
	vb.add_child(list)

	# primary action + debug action
	var actions := HBoxContainer.new()
	if opts.get("broken_noop", false):
		actions.add_child(_noop_button("Refresh"))
	else:
		actions.add_child(_action_button("Refresh", &"timeline.refresh_prediction", "rebuild prediction"))
	actions.add_child(_action_button("Copy Debug", &"debug.copy_report", "copy debug report"))
	vb.add_child(actions)
	return root


static func _row(index: int, entry_id: String, tick: int, tie: bool, float_tick: bool, debug_leak: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.set_meta(&"ui_metric_id", StringName("timeline_row_%d" % index))
	hb.set_meta(&"ui_metric_role", &"timeline_row")
	hb.set_meta(&"ui_metric_surface", &"timeline_dock")
	hb.set_meta(&"ui_entry_id", entry_id)

	var order_index := Label.new()
	order_index.text = str(index + 1)
	order_index.custom_minimum_size = Vector2(24, 0)
	order_index.set_meta(&"ui_metric_role", &"order_index")
	hb.add_child(order_index)

	var tick_badge := Label.new()
	tick_badge.text = ("%0.1f" % float(tick)) if float_tick else str(tick)
	tick_badge.custom_minimum_size = Vector2(32, 0)
	tick_badge.set_meta(&"ui_metric_role", &"tick_badge")
	hb.add_child(tick_badge)

	var actor := Label.new()
	actor.text = "Slime" if not debug_leak else "res://actors/slime.tres"
	actor.custom_minimum_size = Vector2(80, 0)
	actor.set_meta(&"ui_metric_role", &"actor_label")
	hb.add_child(actor)

	var action := Label.new()
	action.text = "Strike"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.clip_text = true
	action.set_meta(&"ui_metric_role", &"action_label")
	hb.add_child(action)

	if tie:
		hb.add_child(_status_glyph(&"cause_icon", "tie-break: lower id first"))
	return hb


# --- config_panel synthetic tree ------------------------------------------
static func _config_panel_empty(dock_size: Vector2, opts: Dictionary = {}) -> Control:
	var root := _root(dock_size, &"config_panel")
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(vb)

	var picker := Control.new()
	picker.custom_minimum_size = Vector2(180, 24)
	picker.set_meta(&"ui_metric_role", &"resource_picker")
	picker.set_meta(&"ui_picker_base_type", "EQConfig")
	picker.set_meta(&"ui_picker_has_resource", false)
	vb.add_child(picker)

	if opts.get("boolean_text", false):
		var bad := Label.new()
		bad.text = "true"  # boolean state as text -> P0 modality
		bad.set_meta(&"ui_metric_role", &"status_text")
		vb.add_child(bad)
	else:
		var status := _status_glyph(&"status_icon", "no config selected")
		vb.add_child(status)

	var empty := Label.new()
	empty.text = "Select a config"
	empty.set_meta(&"ui_metric_role", &"empty_state")
	empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(empty)
	return root


# --- shared helpers --------------------------------------------------------
static func _root(dock_size: Vector2, surface: StringName) -> Control:
	var root := Control.new()
	root.custom_minimum_size = dock_size
	root.size = dock_size
	root.set_meta(&"ui_metric_role", &"screen_root")
	root.set_meta(&"ui_metric_surface", surface)
	return root


static func _status_glyph(role: StringName, tooltip: String) -> Control:
	var tr := TextureRect.new()
	tr.texture = PlaceholderTexture2D.new()
	tr.custom_minimum_size = Vector2(16, 16)
	tr.tooltip_text = tooltip
	tr.set_meta(&"ui_metric_role", role)
	return tr


static func _action_button(text: String, action_id: StringName, effect: String) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta(&"ui_action_id", action_id)
	b.set_meta(&"ui_action_effect", effect)
	b.set_meta(&"ui_metric_role", &"primary_action")
	b.pressed.connect(func(): pass)  # real connection (not a no-op audit target)
	return b


static func _noop_button(text: String) -> Button:
	var b := Button.new()
	b.text = text  # no connection, no action_id -> P0 no-op
	b.set_meta(&"ui_metric_role", &"primary_action")
	return b


static func _starved_title(text: String) -> Control:
	var hb := HBoxContainer.new()
	var title := Label.new()
	title.text = text
	title.clip_text = true
	title.custom_minimum_size = Vector2(40, 0)
	title.set_meta(&"ui_metric_role", &"section")
	title.set_meta(&"ui_metric_required", true)
	hb.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(300, 0)
	hb.add_child(spacer)
	return hb
