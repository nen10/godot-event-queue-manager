extends RefCounted
## EQM-083: runtime timeline HUD + debug overlay. Projection-first and headless:
## the HUD renders an injected prediction verbatim (no UI-side recomputation),
## shows explicit stale/empty states, and carries ui_metric_id metadata. Tested
## by structure/state/metadata, not screenshots (UI_TESTABILITY_POLICY).

const EQTimelineHud := preload("res://addons/event_queue_manager/runtime/ui/eq_timeline_hud.gd")
const EQDebugOverlay := preload("res://addons/event_queue_manager/runtime/ui/eq_debug_overlay.gd")


static func run(t) -> void:
	_test_projection_integrity(t)
	_test_stale_state(t)
	_test_empty_state(t)
	_test_metric_metadata(t)
	_test_debug_overlay(t)


static func _test_projection_integrity(t) -> void:
	var hud = EQTimelineHud.new()
	hud.set_state([&"rogue", &"hero", &"golem"])
	# the projected order equals the injected order — the HUD never re-sorts
	t.eq(hud.order(), [&"rogue", &"hero", &"golem"], "HUD shows the injected order verbatim (projection integrity)")
	var rows: Array = hud.rows()
	t.eq(rows.size(), 3, "one row per injected entry")
	# row 0 label is the first injected actor (no reordering)
	var first_label_text := ""
	for c in (rows[0] as Node).get_children():
		if c is Label and not c.has_meta(&"ui_metric_role"):
			first_label_text = c.text
	t.eq(first_label_text, "rogue", "first row renders the first injected actor")
	hud.free()


static func _test_stale_state(t) -> void:
	var hud = EQTimelineHud.new()
	hud.set_state([&"hero"], false)
	t.ok(not hud.is_stale(), "not stale by default")
	hud.set_stale(true)
	t.ok(hud.is_stale(), "stale flag reflected")
	# the stale indicator (a non-text badge) becomes visible
	var indicator: Control = null
	for c in hud.get_children():
		if c.has_meta(&"ui_metric_role") and c.get_meta(&"ui_metric_role") == &"stale_indicator":
			indicator = c
	t.ok(indicator != null and indicator.visible, "stale indicator visible while presentation is deferred")
	hud.free()


static func _test_empty_state(t) -> void:
	var hud = EQTimelineHud.new()
	hud.set_state([])
	t.ok(hud.is_empty_state(), "explicit empty state for an empty prediction")
	var has_empty_marker := false
	for c in hud.get_children():
		if c.has_meta(&"ui_metric_role") and c.get_meta(&"ui_metric_role") == &"empty_state":
			has_empty_marker = true
	t.ok(has_empty_marker, "empty state is an explicit marker, not a silent blank")
	hud.free()


static func _test_metric_metadata(t) -> void:
	var hud = EQTimelineHud.new()
	hud.set_state([&"a", &"b"])
	for row in hud.rows():
		t.ok((row as Node).has_meta(&"ui_metric_id"), "each row carries a ui_metric_id")
		t.eq((row as Node).get_meta(&"ui_metric_surface"), &"timeline_hud", "rows tagged with the surface")
	hud.free()


static func _test_debug_overlay(t) -> void:
	var ov = EQDebugOverlay.new()
	ov.set_state([&"hero", &"orc"], [{"decided_by": &"priority"}, {"decided_by": &"sequence"}])
	t.eq(ov.order(), [&"hero", &"orc"], "debug overlay shows the injected live order")
	t.eq(ov.explanation_for(0)["decided_by"], &"priority", "why-next explanation data is held (explanation-as-data)")
	t.eq(ov.rows().size(), 2, "one debug row per entry")
	ov.free()
