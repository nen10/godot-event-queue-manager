extends RefCounted
## EQM-101: the energy/threshold demo runs headless and is approval-tested against
## a golden trace (DETERMINISM_TRACE_TEST_POLICY §5). Public API only; learning
## path, not a default.

const EnergyBattle := preload("res://demos/energy_battle/energy_battle.gd")

const CASE := "demo_energy_battle"
const GOLDEN_PATH := "res://tests/golden/demo_energy_battle.trace.jsonl"
const TURNS := 9


static func run(t) -> void:
	var jsonl: String = EnergyBattle.run_trace(TURNS)
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
		t.eq(jsonl, FileAccess.get_file_as_string(GOLDEN_PATH), "energy demo trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % CASE)
	# sanity: the fastest accruer (rogue, speed 22) crosses the threshold first
	var first_line: String = jsonl.split("\n")[0]
	t.ok(first_line.contains("\"actor\":\"rogue\""), "fastest energy accruer acts first")
