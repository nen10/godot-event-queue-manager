extends RefCounted
## EQM-091 — the editor order inspector through the EQM-087 collector. The
## explanation rows render structured factors (key label + integer value + cause
## icon), the deciding factor is marked, and the empty state shows when nothing is
## selected. No free-form string, no debug leak, no float value.

const EQEntry := preload("res://addons/event_queue_manager/runtime/eq_entry.gd")
const EQDebugInspector := preload("res://addons/event_queue_manager/editor/debug_inspector.gd")
const Collector := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd")
const Evaluator := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_metric_evaluator.gd")


static func run(tree: SceneTree, t) -> void:
	await _test_renders_explanation(tree, t)
	_test_empty_state(t)


static func _e(tick: int, priority: int, sequence: int, actor: StringName) -> EQEntry:
	return EQEntry.make(sequence, tick, priority, sequence, &"turn", actor)


static func _test_renders_explanation(tree: SceneTree, t) -> void:
	var inspector = EQDebugInspector.new()
	# orc placed after hero by priority (same tick)
	inspector.select(_e(4, 2, 2, &"orc"), _e(4, 5, 1, &"hero"))

	t.eq(inspector.factor_rows().size(), 3, "one explanation row per ordering factor")
	t.eq(inspector.decided_by(), &"priority", "deciding factor surfaced to the UI")
	t.ok(not inspector.is_empty_state(), "selection -> not empty state")

	# flush layout and read back through the collector
	var win := tree.root
	win.set_size(Vector2i(420, 720))
	inspector.size = Vector2(420, 720)
	inspector.custom_minimum_size = Vector2(420, 720)
	win.add_child(inspector)
	await tree.process_frame
	await tree.process_frame

	var snapshot: Dictionary = Collector.collect(inspector, &"order_inspector", Vector2(420, 720))
	var findings: Array = Evaluator.evaluate(snapshot, {"dock_class": "normal"})
	t.ok(not _has(findings, "debug_leakage", "P0"), "no debug leakage in the inspector")
	t.ok(not _has(findings, "modality", "P0"), "no boolean-text state in the inspector")

	# the value cells are integers (no float ordering leaked), and a deciding icon exists
	var saw_value := false
	var saw_decider := false
	for n in snapshot["nodes"]:
		if n["role"] == "explanation_value":
			saw_value = true
			t.ok(not n["text"].contains("."), "factor value is integer (no float): '%s'" % n["text"])
		if n["role"] == "cause_icon" and n["has_status_glyph"]:
			saw_decider = true
	t.ok(saw_value, "explanation values rendered")
	t.ok(saw_decider, "cause icons rendered (deciding factor marked)")

	win.remove_child(inspector)
	inspector.free()


static func _test_empty_state(t) -> void:
	var inspector = EQDebugInspector.new()
	inspector.select(null)
	t.ok(inspector.is_empty_state(), "no selection -> empty state")
	t.eq(inspector.factor_rows().size(), 0, "no selection -> no factor rows")
	inspector.free()


static func _has(findings: Array, metric: String, severity: String) -> bool:
	for f in findings:
		if f["metric"] == metric and f["severity"] == severity:
			return true
	return false
