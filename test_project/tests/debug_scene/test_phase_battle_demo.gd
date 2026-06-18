extends RefCounted
## EQM-101: the team-phase demo runs headless and is approval-tested against a
## golden trace. Public API only; phases via initiative bands (no phase policy).

const PhaseBattle := preload("res://demos/phase_battle/phase_battle.gd")

const CASE := "demo_phase_battle"
const GOLDEN_PATH := "res://tests/golden/demo_phase_battle.trace.jsonl"
const TURNS := 8  # two full rounds of 4


static func run(t) -> void:
	var jsonl: String = PhaseBattle.run_trace(TURNS)
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
		t.eq(jsonl, FileAccess.get_file_as_string(GOLDEN_PATH), "phase demo trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % CASE)
	# sanity: the whole ally band precedes the whole enemy band within round 1
	var actors: Array = []
	for line in jsonl.split("\n", false):
		var d = JSON.parse_string(line)
		if d != null and d.get("kind", "") == "resolved":
			actors.append(String(d["actor"]))
	t.ok(actors.size() >= 4, "phase demo produced a round")
	var first_round: Array = actors.slice(0, 4)
	var ally_idx_max := maxi(first_round.find("knight"), first_round.find("cleric"))
	var enemy_idx_min := mini(first_round.find("orc"), first_round.find("goblin"))
	t.ok(ally_idx_max < enemy_idx_min, "ally phase fully precedes enemy phase in round 1: %s" % str(first_round))
