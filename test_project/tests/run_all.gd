extends SceneTree
## Headless test runner for tools/test.sh.
##
## Discovers res://tests/**/test_*.gd in sorted (deterministic) order, calls
## each file's `static func run(t)`, and aggregates. Exit 0 = pass.

const EQTest := preload("res://tests/eq_test.gd")


func _initialize() -> void:
	var info := Engine.get_version_info()
	print("[run_all] engine %s.%s.%s" % [info["major"], info["minor"], info["patch"]])

	var t := EQTest.new()
	var files := _discover("res://tests")
	files.sort()
	for path in files:
		var script: GDScript = load(path)
		if script == null:
			t.ok(false, "failed to load %s" % path)
			continue
		script.run(t)

	print("[run_all] files=%d checks=%d failures=%d" % [files.size(), t.checks, t.failures.size()])
	if t.failures.is_empty():
		print("[run_all] PASS")
		quit(0)
	else:
		for f in t.failures:
			printerr("[run_all] FAIL: %s" % f)
		quit(1)


func _discover(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if d.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_discover(full))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out
