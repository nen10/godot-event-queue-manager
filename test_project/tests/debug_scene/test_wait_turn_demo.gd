extends RefCounted
## EQM-041: the wait-turn sample runs headless and is approval-tested against a
## golden trace (DETERMINISM_TRACE_TEST_POLICY §5). Public API only; learning path.

const WaitTurn := preload("res://demos/wait_turn_tactics/wait_turn.gd")

const CASE := "demo_wait_turn"
const GOLDEN_PATH := "res://tests/golden/demo_wait_turn.trace.jsonl"
const TURNS := 9


static func run(t) -> void:
	var jsonl: String = WaitTurn.run_trace(TURNS)
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
		t.eq(jsonl, FileAccess.get_file_as_string(GOLDEN_PATH), "wait-turn demo trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % CASE)

	# archer has the smallest wait (4), so it acts first
	var first_line: String = jsonl.split("\n")[0]
	t.ok(first_line.contains("\"actor\":\"archer\""), "smallest-wait unit (archer) acts first")
