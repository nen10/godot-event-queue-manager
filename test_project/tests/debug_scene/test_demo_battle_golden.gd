extends RefCounted
## EQM-101: the Action Resolution demo (demos/action_resolution/demo_battle.gd) as
## the suite's action-resolution member — approval-tested against a golden trace.
## (test_action_resolution_demo.gd covers determinism + API usage; this fixes the
## byte trace.) Public API only.

const DemoBattle := preload("res://demos/action_resolution/demo_battle.gd")

const CASE := "demo_action_resolution"
const GOLDEN_PATH := "res://tests/golden/demo_action_resolution.trace.jsonl"
const TURNS := 8


static func run(t) -> void:
	var jsonl: String = DemoBattle.run_trace(TURNS)
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == CASE:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
		var fw := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		if fw == null:
			t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
			return
		fw.store_string(jsonl)
		fw.close()
		t.ok(true, "demo golden re-baselined for %s via --update-golden" % CASE)
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "demo golden exists: %s (create via ./tools/test.sh --update-golden %s)" % [GOLDEN_PATH, CASE])
	if exists:
		t.eq(jsonl, FileAccess.get_file_as_string(GOLDEN_PATH), "action-resolution demo trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % CASE)
	# sanity: the demo exercises reservation/trigger + presentation
	t.ok(jsonl.contains("reaction_fired"), "armed reaction fires")
	t.ok(jsonl.contains("presentation_flush"), "presentation buffer flushes")
