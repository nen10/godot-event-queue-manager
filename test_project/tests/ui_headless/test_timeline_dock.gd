extends RefCounted
## EQM-090 — real Timeline Preview Dock through the EQM-087 metric harness.
## Runs in the UI phase (needs frame-flushed layout). Projection integrity is the
## central assertion: ui_order read from the laid-out dock rows MUST equal an
## INDEPENDENT EQPrediction.predict_turns — so a row-building bug is caught, not
## hidden. Empty/validation states and ui_metric metadata are asserted too.

const EQTimelineDock := preload("res://addons/event_queue_manager/editor/timeline_dock.gd")
const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQPrediction := preload("res://addons/event_queue_manager/runtime/eq_prediction.gd")
const EQFixedRoundPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd")
const Collector := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd")
const Evaluator := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_metric_evaluator.gd")


static func run(tree: SceneTree, t) -> void:
	await _test_projection_integrity(tree, t)
	_test_empty_state(t)
	_test_validation_state(t)


static func _make_runtime() -> EQRuntime:
	var config := EQConfig.new()
	config.policy = EQFixedRoundPolicy.new()
	config.tie_break = &"actor_id"
	var rt := EQRuntime.new(config, EQRuntime.Mode.DEV)
	rt.emit_engine_diagnostics = false
	rt.register_actor(&"hero").data["initiative"] = 30
	rt.register_actor(&"orc").data["initiative"] = 10
	rt.register_actor(&"mage").data["initiative"] = 20
	config.policy.seed(rt, rt.registry.actor_ids())
	return rt


static func _test_projection_integrity(tree: SceneTree, t) -> void:
	var config := EQConfig.new()
	config.policy = EQFixedRoundPolicy.new()
	config.tie_break = &"actor_id"
	var rt := _make_runtime()

	# independent headless prediction (the oracle)
	var expected: Array = EQPrediction.predict_turns(rt, 5)
	t.ok(expected.size() >= 3, "predict produced an order to project")

	var dock = EQTimelineDock.new()
	dock.set_preview(rt.config, rt, 5)

	# flush layout (headless Control rects only resolve across frames)
	var win := tree.root
	win.set_size(Vector2i(420, 720))
	dock.size = Vector2(420, 720)
	dock.custom_minimum_size = Vector2(420, 720)
	win.add_child(dock)
	await tree.process_frame
	await tree.process_frame

	# dock's own accessor matches the prediction
	t.eq(dock.order(), expected, "dock.order() == independent prediction")

	# AND the laid-out rows, read back through the collector, match (projection metric)
	var snapshot: Dictionary = Collector.collect(dock, &"timeline_dock", Vector2(420, 720))
	var context := {"dock_class": "normal", "headless_order": expected, "next_n": 5}
	var findings: Array = Evaluator.evaluate(snapshot, context)
	t.ok(not _has(findings, "projection_integrity", "P0"), "laid-out dock rows match prediction (projection integrity)")
	t.eq(Evaluator.summarize(findings)["P1"], 0, "real dock is P1-clean (M5 gate)")
	t.eq(dock.row_count(), expected.size(), "one row per predicted turn (windowed to N)")

	# metadata present on the rows (harness can read stable roles)
	var has_row := false
	for n in snapshot["nodes"]:
		if n["role"] == "timeline_row":
			has_row = true
			break
	t.ok(has_row, "rows carry ui_metric_role metadata")

	win.remove_child(dock)
	dock.free()


static func _test_empty_state(t) -> void:
	var dock = EQTimelineDock.new()
	dock.set_preview(null, null, 5)  # no config -> empty state, never a sample default
	t.ok(dock.is_empty_state(), "no config -> empty_state (no silent sample default)")
	t.eq(dock.row_count(), 0, "no config -> zero rows")
	t.ok(dock.order().is_empty(), "no config -> empty order")
	dock.free()


static func _test_validation_state(t) -> void:
	var dock = EQTimelineDock.new()
	var config := EQConfig.new()  # policy unset -> POLICY_MISSING
	var rt := EQRuntime.new(config, EQRuntime.Mode.DEV)
	dock.set_preview(config, rt, 5)
	t.ok(dock.is_validation_state(), "invalid config -> validation state")
	t.ok(not dock.validation_messages().is_empty(), "validation messages surfaced")
	t.eq(dock.row_count(), 0, "invalid config -> no timeline rows")
	dock.free()


static func _has(findings: Array, metric: String, severity: String) -> bool:
	for f in findings:
		if f["metric"] == metric and f["severity"] == severity:
			return true
	return false
