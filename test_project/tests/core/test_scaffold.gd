extends RefCounted
## Scaffold smoke as a test: the addon is reachable from this clean consumer
## project and the engine meets the declared minimum.

const EQVersion := preload("res://addons/event_queue_manager/runtime/eq_version.gd")


static func run(t) -> void:
	t.ok(FileAccess.file_exists("res://addons/event_queue_manager/plugin.cfg"), "addon plugin.cfg reachable from test_project")
	t.ok(EQVersion.is_supported_engine(), "engine meets declared minimum %d.%d" % [EQVersion.MIN_GODOT_MAJOR, EQVersion.MIN_GODOT_MINOR])
