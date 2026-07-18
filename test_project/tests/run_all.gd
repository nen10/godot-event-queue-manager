extends SceneTree
## Headless test runner for tools/test.sh.
##
## Discovers one explicit suite in sorted (deterministic) order, calls each
## file's `static func run(t)`, and aggregates. Exit 0 = pass.

const EQTest := preload("res://tests/eq_test.gd")
const REGRESSION_SUITE := "regression"
const PERFORMANCE_SUITE := "performance"
const PERFORMANCE_ROOT := "res://tests/performance"


func _initialize() -> void:
	var info := Engine.get_version_info()
	print("[run_all] engine %s.%s.%s" % [info["major"], info["minor"], info["patch"]])

	var suite := OS.get_environment("EQ_TEST_SUITE")
	if suite == "":
		suite = REGRESSION_SUITE
	if suite != REGRESSION_SUITE and suite != PERFORMANCE_SUITE:
		_fail_suite("unknown suite: %s" % suite)
		return
	if suite == PERFORMANCE_SUITE and OS.get_environment("GODOT_UPDATE_GOLDEN") != "":
		_fail_suite("performance suite does not allow golden updates")
		return

	var t := EQTest.new()
	var files: Array[String]
	if suite == PERFORMANCE_SUITE:
		files = _discover(PERFORMANCE_ROOT)
	else:
		files = _discover("res://tests", {PERFORMANCE_ROOT: true})
	files.sort()
	if files.is_empty():
		_fail_suite("suite %s discovered zero test files" % suite)
		return
	for path in files:
		var is_performance := path.begins_with(PERFORMANCE_ROOT + "/")
		if (suite == PERFORMANCE_SUITE) != is_performance:
			_fail_suite("suite boundary violation: %s contains %s" % [suite, path])
			return
	print("[run_all] suite=%s discovered=%d" % [suite, files.size()])
	for path in files:
		var script: GDScript = load(path)
		if script == null:
			t.ok(false, "failed to load %s" % path)
			continue
		script.run(t)

	# UI metric phase (frame-stepping; excluded from sync discovery above because
	# headless Control layout only resolves across process frames). EQM-087.
	if suite == REGRESSION_SUITE:
		var ui_runner: GDScript = load("res://tests/ui_headless/run_ui_metrics.gd")
		if ui_runner != null:
			await ui_runner.run(self, t, OS.get_environment("EQ_RUN_OUT"))

	print("[run_all] suite=%s files=%d checks=%d failures=%d" % [suite, files.size(), t.checks, t.failures.size()])
	if t.failures.is_empty():
		print("[run_all] PASS")
		quit(0)
	else:
		for f in t.failures:
			printerr("[run_all] FAIL: %s" % f)
		quit(1)


func _discover(dir_path: String, excluded_paths: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			# ui_headless/ holds frame-stepping modules run by the UI phase, not
			# the synchronous discovery loop (they need a flushed layout + results).
			if not entry.begins_with(".") and entry != "ui_headless" and not excluded_paths.has(full):
				out.append_array(_discover(full, excluded_paths))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out


func _fail_suite(message: String) -> void:
	printerr("[run_all] FAIL: %s" % message)
	quit(1)
