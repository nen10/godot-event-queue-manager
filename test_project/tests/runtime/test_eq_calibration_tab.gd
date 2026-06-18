extends RefCounted
## EQM-094 — the Layout Calibration tab. Acceptance (UI_LAYOUT_CALIBRATION_POLICY
## §7): the tab is invisible without the flag (P0), and Copy Layout Feedback emits
## schema-valid JSON containing only layout params.

const EQCalibrationTab := preload("res://addons/event_queue_manager/editor/testing/eq_calibration_tab.gd")


static func run(t) -> void:
	_test_hidden_without_flag(t)
	_test_visible_with_flag(t)
	_test_feedback_schema(t)
	_test_feedback_no_paths(t)
	_test_reset(t)


static func _test_hidden_without_flag(t) -> void:
	# no force flag; the test env does not set EQ_EDITOR_CALIBRATION
	var tab = EQCalibrationTab.new()
	t.ok(not tab.is_enabled(), "calibration disabled without the flag")
	t.ok(not tab.visible, "calibration tab invisible in normal mode (§6 P0)")
	tab.free()


static func _test_visible_with_flag(t) -> void:
	var tab = EQCalibrationTab.new(true)  # inject the flag
	t.ok(tab.is_enabled() and tab.visible, "calibration tab visible behind the flag")
	tab.free()


static func _make_target(tab) -> Array:
	var a := Label.new()
	a.set_meta(&"ui_metric_id", &"timeline.row.actor_label")
	a.custom_minimum_size = Vector2(60, 0)
	var b := Label.new()
	b.set_meta(&"ui_metric_id", &"timeline.row.cause_icon")
	tab.set_target(&"timeline_dock", [a, b])
	return [a, b]


static func _test_feedback_schema(t) -> void:
	var tab = EQCalibrationTab.new(true)
	var pair := _make_target(tab)
	var actor: Label = pair[0]

	t.ok(tab.edit(&"timeline.row.actor_label", "custom_minimum_size.x", 96), "edit applies")
	t.eq(actor.custom_minimum_size.x, 96.0, "edit reflected live on the control")

	var fb: Dictionary = tab.layout_feedback("small_queue_3_actors", Vector2(420, 720), 1.0, "wider names")
	t.eq(fb["kind"], "eq_layout_feedback", "schema kind")
	t.eq(fb["version"], 1, "schema version")
	t.eq(fb["surface"], "timeline_dock", "surface present")
	t.eq(fb["scenario"], "small_queue_3_actors", "scenario present")
	t.eq(fb["dock_size"], [420.0, 720.0], "dock_size present")
	t.ok(fb.has("ui_scale") and fb.has("timestamp"), "ui_scale + timestamp present")
	t.eq((fb["edited"] as Array).size(), 1, "one edited entry")
	var e0: Dictionary = fb["edited"][0]
	t.ok(e0["id"] == "timeline.row.actor_label" and e0["param"] == "custom_minimum_size.x"
		and e0["old"] == 60.0 and e0["new"] == 96, "edited entry has id/param/old/new")
	# untouched lists the control never edited
	t.ok((fb["untouched"] as Array).has("timeline.row.cause_icon"), "untouched control listed")

	# JSON form parses back to the same structure
	var parsed = JSON.parse_string(tab.layout_feedback_json("small_queue_3_actors", Vector2(420, 720), 1.0))
	t.ok(parsed != null and parsed["kind"] == "eq_layout_feedback", "feedback JSON is valid + schema-conformant")
	tab.free()


static func _test_feedback_no_paths(t) -> void:
	# §3: layout params only — no file path / node path / project info anywhere
	var tab = EQCalibrationTab.new(true)
	_make_target(tab)
	tab.edit(&"timeline.row.actor_label", "size_flags_horizontal", 3)
	var json := tab.layout_feedback_json("narrow", Vector2(320, 600), 1.25)
	for forbidden in ["res://", "user://", "/root/", "NodePath", ".gd", "@"]:
		t.ok(not json.contains(forbidden), "feedback JSON excludes '%s'" % forbidden)
	tab.free()


static func _test_reset(t) -> void:
	var tab = EQCalibrationTab.new(true)
	var pair := _make_target(tab)
	var actor: Label = pair[0]
	tab.edit(&"timeline.row.actor_label", "custom_minimum_size.x", 96)
	tab.reset_surface()
	t.eq(actor.custom_minimum_size.x, 60.0, "reset restores the original value")
	var fb: Dictionary = tab.layout_feedback("s", Vector2(420, 720), 1.0)
	t.eq((fb["edited"] as Array).size(), 0, "reset clears the edited list")
	tab.free()
