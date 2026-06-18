extends RefCounted
## EQM-087 — frame-stepping UI metric phase (UI_LAYOUT_METRIC_TEST_POLICY §2.2
## Pass A). Invoked by run_all.gd AFTER the synchronous unit tests, because
## headless Control layout only resolves across process frames (empirically:
## explicit root size + 2 process_frame awaits yields real rects).
##
## For each scenario × acceptance dock size: build → flush layout → collect →
## evaluate. Findings are REPORT-ONLY at adoption M1-M3 (WARN-only); the build is
## gated only by the three test modules' structural assertions (good→no P0,
## broken→matching P0), which prove the metrics are non-tautological. M4/M5
## (EQM-094/095) flips finding severities to hard-fail.

const Collector := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_snapshot_collector.gd")
const Evaluator := preload("res://addons/event_queue_manager/editor/testing/eq_ui_layout_metric_evaluator.gd")
const Builder := preload("res://addons/event_queue_manager/editor/testing/eq_ui_state_scenario_builder.gd")

const TestLayout := preload("res://tests/ui_headless/test_editor_layout_metrics.gd")
const TestState := preload("res://tests/ui_headless/test_editor_state_matrix.gd")
const TestInteraction := preload("res://tests/ui_headless/test_editor_interaction_contract.gd")
const TestTimelineDock := preload("res://tests/ui_headless/test_timeline_dock.gd")
const TestDebugInspector := preload("res://tests/ui_headless/test_debug_inspector.gd")
const TestTemplateGenerator := preload("res://tests/ui_headless/test_template_generator.gd")

const DOCK_SIZES := [Vector2(320, 600), Vector2(420, 720)]


static func run(tree: SceneTree, t, out_dir: String) -> void:
	var results: Array = []
	for sc in Builder.scenarios():
		for dock in DOCK_SIZES:
			var res: Dictionary = await _evaluate_one(tree, sc, dock)
			results.append(res)

	var agg: Dictionary = _aggregate(results)
	print("[ui_metrics] scenarios=%d evaluations=%d P0=%d P1=%d WARN=%d (M5: P0+P1 enforced on real/good surfaces)"
		% [Builder.scenarios().size(), results.size(), agg["P0"], agg["P1"], agg["WARN"]])

	if out_dir != "":
		_write_report(out_dir, results, agg)

	# M4 gate (EQM-093): P0 on any non-broken scenario FAILS the build.
	# M5 gate (EQM-095): P1 likewise enforced (row geometry, truncation, picker width).
	# broken_* are the evaluator's self-test (they MUST produce P0) and are excluded.
	_enforce(results, t)

	# structural gates (these DO fail the build) — the harness's own correctness
	TestLayout.run(t, results)
	TestState.run(t, results)
	TestInteraction.run(t, results)
	# real editor surfaces fed through the same collector (EQM-090+)
	await TestTimelineDock.run(tree, t)
	await TestDebugInspector.run(tree, t)
	await TestTemplateGenerator.run(tree, t)


static func _evaluate_one(tree: SceneTree, sc: Dictionary, dock: Vector2) -> Dictionary:
	var win := tree.root
	win.set_size(Vector2i(int(dock.x), int(dock.y)))
	var root: Control = Builder.build(sc["name"], dock)
	root.size = dock
	root.custom_minimum_size = dock
	win.add_child(root)
	await tree.process_frame
	await tree.process_frame

	var surface: StringName = StringName(sc.get("surface", "unknown"))
	var snapshot: Dictionary = Collector.collect(root, surface, dock)
	var context: Dictionary = {"dock_class": _dock_class(dock)}
	if sc.has("headless_order"):
		context["headless_order"] = sc["headless_order"]
		context["next_n"] = sc.get("next_n", 10)
	var findings: Array = Evaluator.evaluate(snapshot, context)

	win.remove_child(root)
	root.free()

	return {
		"name": sc["name"],
		"surface": sc.get("surface", ""),
		"kind": sc.get("kind", "good"),
		"metric": sc.get("metric", ""),
		"dock_class": _dock_class(dock),
		"dock_size": [dock.x, dock.y],
		"node_count": (snapshot["nodes"] as Array).size(),
		"findings": findings,
		"summary": Evaluator.summarize(findings),
	}


## M4/M5 enforcement: every P0 (M4) and P1 (M5) finding on a non-broken scenario
## is a build failure. broken_* are excluded (they MUST raise findings — self-test).
static func _enforce(results: Array, t) -> void:
	const ENFORCED_P0 := ["noop_button", "scroll_reachability", "state_contradiction",
		"debug_leakage", "projection_integrity", "sample_separation", "modality", "truncation"]
	const ENFORCED_P1 := ["timeline_geometry", "truncation", "modality"]  # row geometry, picker width, non-primary truncation
	var p0 := 0
	var p1 := 0
	for r in results:
		if r["kind"] == "broken":
			continue
		for f in r["findings"]:
			if f["severity"] == "P0":
				p0 += 1
				t.ok(false, "[M4 P0 gate] %s/%s/%s: %s.%s — %s"
					% [r["surface"], r["name"], r["dock_class"], f["metric"], f["id"], f["message"]])
			elif f["severity"] == "P1":
				p1 += 1
				t.ok(false, "[M5 P1 gate] %s/%s/%s: %s.%s — %s"
					% [r["surface"], r["name"], r["dock_class"], f["metric"], f["id"], f["message"]])
	t.ok(p0 == 0, "[M4 P0 gate] no P0 across non-broken scenarios (enforced: %s)" % str(ENFORCED_P0))
	t.ok(p1 == 0, "[M5 P1 gate] no P1 across non-broken scenarios (enforced: %s)" % str(ENFORCED_P1))


static func _dock_class(dock: Vector2) -> String:
	if dock.x <= 320.0:
		return "narrow"
	if dock.x <= 420.0:
		return "normal"
	return "wide"


static func _aggregate(results: Array) -> Dictionary:
	var p0 := 0
	var p1 := 0
	var warn := 0
	for r in results:
		var s: Dictionary = r["summary"]
		p0 += s["P0"]
		p1 += s["P1"]
		warn += s["WARN"]
	return {"P0": p0, "P1": p1, "WARN": warn}


static func _write_report(out_dir: String, results: Array, agg: Dictionary) -> void:
	var json := {
		"date": Time.get_date_string_from_system(),
		"engine": "%s" % Engine.get_version_info().get("string", ""),
		"adoption": "M4 (P0 enforced on real/good surfaces; broken_* self-test)",
		"aggregate": agg,
		"results": results,
	}
	_write(out_dir.path_join("ui_metrics.json"), JSON.stringify(json, "  "))
	_write(out_dir.path_join("ui_metrics.md"), _markdown(results, agg))


static func _markdown(results: Array, agg: Dictionary) -> String:
	var lines: Array = []
	lines.append("# Editor UI Metrics Report")
	lines.append("")
	lines.append("Adoption: M1-M3 (WARN-only). Findings are reported, not gating, until M4/M5.")
	lines.append("")
	lines.append("## Summary")
	lines.append("- P0 findings: %d" % agg["P0"])
	lines.append("- P1 findings: %d" % agg["P1"])
	lines.append("- Warnings: %d" % agg["WARN"])
	lines.append("")
	lines.append("## Findings by scenario")
	for r in results:
		var s: Dictionary = r["summary"]
		if s["total"] == 0:
			continue
		lines.append("### %s / %s (%s, %s)" % [r["surface"], r["name"], r["kind"], r["dock_class"]])
		for f in r["findings"]:
			lines.append("- [%s] %s.%s — %s" % [f["severity"], f["metric"], f["id"], f["message"]])
		lines.append("")
	return "\n".join(lines)


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
