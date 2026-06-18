extends RefCounted
## EQM-092 — the template generator surface. Sample separation: generate()
## produces a BADGED sample that does not satisfy a production slot; only the
## explicit duplicate_to_project() writes project assets. Run through the EQM-087
## collector so §5.10 (sample badged) is enforced on the real surface.

const EQTemplateGenerator := preload("res://addons/event_queue_manager/editor/template_generator.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const Collector := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd")
const Evaluator := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_metric_evaluator.gd")


static func run(tree: SceneTree, t) -> void:
	await _test_sample_then_duplicate(tree, t)


static func _test_sample_then_duplicate(tree: SceneTree, t) -> void:
	var gen = EQTemplateGenerator.new()

	# before generate: nothing satisfies a production slot (no hidden default)
	t.ok(not gen.satisfies_production_slot(), "no artifact -> no production default")

	# generate -> a SAMPLE artifact, badged, not in project
	var sample := gen.generate()
	t.ok(sample["sample"], "generate() yields a sample artifact")
	t.ok(gen.is_sample(), "generator is in sample state")
	t.ok(not gen.satisfies_production_slot(), "a sample never satisfies a production slot (§5.10)")
	t.ok(sample["uses_apis"].has("reservation") and sample["uses_apis"].has("trigger") and sample["uses_apis"].has("presentation"),
		"manifest records reservation/trigger/presentation usage")

	# the sample is visibly badged (collector + §5.10 metric on the real surface)
	var win := tree.root
	win.set_size(Vector2i(420, 720))
	gen.size = Vector2(420, 720)
	gen.custom_minimum_size = Vector2(420, 720)
	win.add_child(gen)
	await tree.process_frame
	await tree.process_frame
	var snapshot: Dictionary = Collector.collect(gen, &"template_generator", Vector2(420, 720))
	var findings: Array = Evaluator.evaluate(snapshot, {"dock_class": "normal"})
	t.ok(not _has(findings, "sample_separation", "P0"), "sample is badged (no sample_separation P0)")
	t.ok(not _has(findings, "noop_button", "P0"), "generate/duplicate buttons are wired")
	t.eq(Evaluator.summarize(findings)["P1"], 0, "real generator is P1-clean (M5 gate)")
	win.remove_child(gen)

	# duplicate_to_project -> explicit bridge writes project assets, clears sample
	var target := "user://eqm092_test_assets"
	var prod := gen.duplicate_to_project(target)
	t.ok(not prod["sample"], "duplicate_to_project() yields production assets")
	t.ok(gen.satisfies_production_slot(), "after explicit duplicate, the artifact may satisfy a production slot")
	# the config asset was actually created and is valid
	var config_path: String = target.path_join("action_resolution_config.tres")
	t.ok(FileAccess.file_exists(config_path), "project config asset created on disk")
	var loaded = load(config_path)
	t.ok(loaded != null and loaded.validate().is_valid(), "created config loads and validates")

	gen.free()


static func _has(findings: Array, metric: String, severity: String) -> bool:
	for f in findings:
		if f["metric"] == metric and f["severity"] == severity:
			return true
	return false
