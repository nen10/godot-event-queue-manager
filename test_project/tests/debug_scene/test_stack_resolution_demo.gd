extends RefCounted
## EQM-101: the LIFO stack demo runs headless and is approval-tested against a
## golden trace. Public L0 API only; the stack is modelled with priority = depth
## so priority-DESC pops the last-pushed item first.

const StackResolution := preload("res://demos/stack_resolution/stack_resolution.gd")

const CASE := "demo_stack_resolution"
const GOLDEN_PATH := "res://tests/golden/demo_stack_resolution.trace.jsonl"


static func run(t) -> void:
	var jsonl: String = StackResolution.run_trace()
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
		t.eq(jsonl, FileAccess.get_file_as_string(GOLDEN_PATH), "stack demo trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % CASE)
	# sanity: LIFO — the last item cast (counter_negate, depth 2) resolves first
	t.eq(StackResolution.resolution_order(), [&"counter_negate", &"response_redirect", &"spell_fireball"],
		"stack resolves LIFO (last cast resolves first)")
