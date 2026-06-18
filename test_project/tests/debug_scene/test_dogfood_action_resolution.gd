extends RefCounted
## EQM-084: the Action Resolution dogfood slice runs headless using the public
## API only, and its canonical trace is approval-tested against a golden
## (DETERMINISM_TRACE_TEST_POLICY §5). The slice exercises AP turns, a counter
## reaction, effect/presentation records, and deterministic RNG end to end.

const Battle := preload("res://dogfood/action_resolution/battle.gd")

const CASE := "dogfood_action_resolution"
const GOLDEN_PATH := "res://tests/golden/dogfood_action_resolution.trace.jsonl"
const TURNS := 8


static func run(t) -> void:
	var jsonl: String = Battle.run_trace(TURNS)
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")

	if update == CASE:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
		var fw := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		if fw == null:
			t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
			return
		fw.store_string(jsonl)
		fw.close()
		t.ok(true, "dogfood golden re-baselined via --update-golden")
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "dogfood golden exists (create via ./tools/test.sh --update-golden %s)" % CASE)
	if exists:
		t.eq(jsonl, FileAccess.get_file_as_string(GOLDEN_PATH), "dogfood trace matches golden")

	# the slice actually exercised the subsystems
	t.ok(jsonl.contains("\"kind\":\"turn\""), "dogfood resolved AP turns")
	t.ok(jsonl.contains("\"kind\":\"effect\""), "dogfood produced effect records (simulation truth)")
	t.ok(jsonl.contains("\"kind\":\"reaction_fired\""), "dogfood fired a counter reaction")
	t.ok(jsonl.contains("\"kind\":\"turn\"") and jsonl.contains("hero"), "hero acted in the slice")
