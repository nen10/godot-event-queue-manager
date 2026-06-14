extends RefCounted
## EQM-034: the CTB sample battle runs headless and its order is approval-tested
## against a golden trace (DETERMINISM_TRACE_TEST_POLICY §5). The sample uses the
## public API only and is a learning path, not a default.

const CTBBattle := preload("res://demos/ctb_battle/ctb_battle.gd")

const CASE := "demo_ctb_battle"
const GOLDEN_PATH := "res://tests/golden/demo_ctb_battle.trace.jsonl"
const TURNS := 9


static func run(t) -> void:
	var jsonl: String = CTBBattle.run_trace(TURNS)
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
		t.eq(jsonl, FileAccess.get_file_as_string(GOLDEN_PATH), "demo trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % CASE)

	# sanity: the faster combatant (rogue, speed 22) takes the first turn
	t.ok(jsonl.contains("\"actor\":\"rogue\""), "demo battle ran and rogue acted")
	var first_line: String = jsonl.split("\n")[0]
	t.ok(first_line.contains("\"actor\":\"rogue\""), "fastest combatant acts first (i=0)")
