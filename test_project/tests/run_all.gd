extends SceneTree
## Headless test runner for tools/test.sh.
## Exit 0 = pass, non-zero = fail.
##
## Scaffold phase (EQM-002): a clean-load smoke that proves the addon is
## reachable from this consumer project and the engine meets the declared
## minimum. Test suites are registered here in later phases.

func _initialize() -> void:
	var info := Engine.get_version_info()
	print("[run_all] engine %s.%s.%s" % [info["major"], info["minor"], info["patch"]])

	var failures: Array[String] = []

	# 1. addon is reachable from this clean consumer project (via addons symlink).
	if not FileAccess.file_exists("res://addons/event_queue_manager/plugin.cfg"):
		failures.append("addon plugin.cfg not reachable from test_project")

	# 2. runtime version helper loads and the engine meets the declared minimum.
	var version_path := "res://addons/event_queue_manager/runtime/eq_version.gd"
	if not ResourceLoader.exists(version_path):
		failures.append("eq_version.gd not found at %s" % version_path)
	else:
		var eq_version: GDScript = load(version_path)
		if not eq_version.is_supported_engine():
			failures.append("engine below declared minimum %d.%d" % [eq_version.MIN_GODOT_MAJOR, eq_version.MIN_GODOT_MINOR])
		else:
			print("[run_all] addon %s on engine %s" % [eq_version.ADDON_VERSION, eq_version.engine_string()])

	if failures.is_empty():
		print("[run_all] PASS (scaffold smoke)")
		quit(0)
	else:
		for f in failures:
			printerr("[run_all] FAIL: %s" % f)
		quit(1)
