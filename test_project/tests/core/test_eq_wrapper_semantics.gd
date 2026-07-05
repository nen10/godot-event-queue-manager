extends RefCounted
## Tests for wrapper standard kinds and relation-chain propagation in state algebra.

const EQStateAlgebra := preload("res://addons/event_queue_manager/runtime/eq_state_algebra.gd")
const EQEventLines := preload("res://addons/event_queue_manager/runtime/eq_event_lines.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")
const EQRelationGraph := preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")

const GOLDEN_CASE := "wrapper_chains"
const GOLDEN_PATH := "res://tests/golden/wrapper_chains.trace.jsonl"


static func run(t) -> void:
	test_inv_chain_semantics(t)
	test_relation_chain_semantics(t)
	test_relation_chain_roundtrip(t)
	test_wrapper_chains_golden(t)


static func test_inv_chain_semantics(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	t.ok(s.declare_inv_pair(&"missing", &"embellish", EQStateAlgebra.Rule.CANCEL), "declare inv pair for inversion")
	s.wrap_state(&"hero", &"missing", {"name": &"inversion", "params": {}, "kind": &"inv_chain"})
	s.grant_state(&"hero", &"missing", 3)
	var axis_line := StringName("eqm.axis.hero.missing__embellish")
	t.eq(lines.value_of(axis_line), -3, "inv_chain on target grant moves to inverse side")
	t.eq(s.active_state(&"hero", &"embellish"), &"embellish", "active state is inverse after inv_chain")
	t.eq(s.stacks_of(&"hero", &"missing"), 0, "inverse pair keeps original side zero")

	var lines2 := EQEventLines.new()
	var s2 := EQStateAlgebra.new(lines2)
	s2.declare_inv_pair(&"missing", &"embellish", EQStateAlgebra.Rule.CANCEL)
	s2.wrap_state(&"hero", &"missing", {"name": &"flip_a", "params": {}, "kind": &"inv_chain"})
	s2.wrap_state(&"hero", &"missing", {"name": &"flip_b", "params": {}, "kind": &"inv_chain"})
	s2.grant_state(&"hero", &"missing", 2)
	var axis_line2 := StringName("eqm.axis.hero.missing__embellish")
	t.eq(lines2.value_of(axis_line2), 2, "double inv_chain on same grant restores declaration order")

	var s3 := EQStateAlgebra.new(EQEventLines.new())
	s3.wrap_state(&"hero", &"depletion", {"name": &"missing_pair", "params": {}, "kind": &"inv_chain"})
	s3.grant_state(&"hero", &"depletion", 4)
	t.eq(s3.faults.size(), 1, "inv_chain without pair is rejected as fault")
	t.eq(s3.faults[0].get("message", ""), "inv_chain wrapper requires a declared pair for state: depletion", "fault message is specific")
	t.eq(s3.stacks_of(&"hero", &"depletion"), 4, "failed inv_chain still grants requested state")

	var tr4 := EQTrace.new()
	var s4 := EQStateAlgebra.new(EQEventLines.new(tr4), tr4)
	s4.wrap_state(&"hero", &"focus", {"name": &"mystery", "params": {"x": 1}, "kind": &"ghost_chain"})
	s4.grant_state(&"hero", &"focus", 5)
	t.eq(s4.stacks_of(&"hero", &"focus"), 5, "unknown wrapper kinds are inert")
	t.ok(not ('"kind":"state_wrapper_applied"' in tr4.to_jsonl()), "inert wrappers never trace an application (regression: applied-record for no-op)")


static func test_relation_chain_semantics(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	var relations := EQRelationGraph.new()
	s.relations = relations

	t.ok(relations.declare_relation_type({"name": &"summon", "structure": EQRelationGraph.Structure.GRAPH}), "declare summon relation type")
	t.ok(relations.declare_relation_type({"name": &"orbit", "structure": EQRelationGraph.Structure.GRAPH}), "declare orbit relation type")
	relations.bind(&"summon", &"moon", &"star")
	relations.bind(&"summon", &"star", &"moon")
	relations.bind(&"orbit", &"star", &"galaxy")

	t.ok(s.declare_inv_pair(&"summon", &"shimmer", EQStateAlgebra.Rule.CANCEL), "declare local inverse for chain target")
	s.wrap_state(&"moon", &"summon", {
		"name": &"chain_moon",
		"kind": &"relation_chain",
		"params": {"relation_type": &"summon", "hop_cost": 1, "budget": 2},
	})
	s.wrap_state(&"star", &"summon", {
		"name": &"star_loop_block",
		"kind": &"relation_chain",
		"params": {"relation_type": &"orbit", "hop_cost": 1, "budget": 4},
	})
	s.wrap_state(&"star", &"summon", {"name": &"star_inverse", "kind": &"inv_chain", "params": {}})
	s.grant_state(&"moon", &"summon", 2)

	t.eq(s.stacks_of(&"moon", &"summon"), 2, "origin gets direct grant")
	t.eq(s.stacks_of(&"star", &"summon"), 0, "chain target flips to inverse state")
	t.eq(s.stacks_of(&"star", &"shimmer"), 2, "inv_chain at chain target applies locally")
	t.eq(s.active_state(&"star", &"shimmer"), &"shimmer", "active state follows inverse at chain target")
	t.eq(s.stacks_of(&"galaxy", &"summon"), 0, "relation_chain wrapper at chain target is not reapplied")
	t.eq(s.faults.size(), 0, "relation_chain propagation with attached relations does not fault")

	var solo := EQStateAlgebra.new(EQEventLines.new())
	solo.wrap_state(&"moon", &"summon", {
		"name": &"bad_chain",
		"kind": &"relation_chain",
		"params": {"relation_type": &"ghost", "hop_cost": 1, "budget": 1},
	})
	solo.grant_state(&"moon", &"summon", 3)
	t.eq(solo.faults.size(), 1, "relation_chain without relations faults")
	t.eq(solo.faults[0].get("message", ""), "relation_chain wrapper requires relations to expand state grants", "missing relations still grants original target")
	t.eq(solo.stacks_of(&"moon", &"summon"), 3, "main grant still applies when relation_chain has no relations")


static func test_relation_chain_roundtrip(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	s.wrap_state(&"hero", &"spark", {
		"name": &"chain_kind",
		"kind": &"relation_chain",
		"params": {"relation_type": &"teleport", "hop_cost": 1, "budget": 2},
	})
	s.wrap_state(&"hero", &"focus", {"name": &"mystery", "kind": &"ghost_chain", "params": {"x": 1}})

	var d := s.to_dict()
	var rebuilt := EQStateAlgebra.new(EQEventLines.new())
	rebuilt.restore(d)
	var wrappers := rebuilt.wrappers_of(&"hero", &"spark")
	t.eq(wrappers.size(), 1, "restore preserves wrapper stack")
	t.eq(StringName(wrappers[0].get("kind", "")), &"relation_chain", "relation kind is restored")
	t.ok(rebuilt.to_dict() == d, "to_dict / restore keeps wrapper kind in roundtrip")


static func test_wrapper_chains_golden(t) -> void:
	var jsonl := _build_wrapper_chains_trace()
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
		var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		if f == null:
			t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
			return
		f.store_string(jsonl)
		f.close()
		t.ok(true, "golden re-baselined for %s via HOME=/tmp godot --headless --path test_project --script res://tests/run_all.gd" % GOLDEN_CASE)
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s" % GOLDEN_PATH)
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		var out := OS.get_environment("EQ_RUN_OUT")
		if out != "":
			DirAccess.make_dir_recursive_absolute(out + "/traces")
			var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
			if f != null:
				f.store_string(jsonl)
				f.close()
		t.eq(jsonl, want, "wrapper chain + inverse chain trace matches golden")


static func _build_wrapper_chains_trace() -> String:
	var tr := EQTrace.new()
	var lines := EQEventLines.new(tr)
	var s := EQStateAlgebra.new(lines, tr)
	var relations := EQRelationGraph.new(tr)
	s.relations = relations

	relations.declare_relation_type({"name": &"summon", "structure": EQRelationGraph.Structure.GRAPH})
	relations.bind(&"summon", &"moon", &"star")
	s.declare_inv_pair(&"summon", &"shimmer", EQStateAlgebra.Rule.CANCEL)
	s.wrap_state(&"moon", &"summon", {
		"name": &"chain_moon",
		"kind": &"relation_chain",
		"params": {"relation_type": &"summon", "hop_cost": 1, "budget": 2},
	})
	s.wrap_state(&"star", &"summon", {"name": &"inverse_star", "kind": &"inv_chain", "params": {}})
	s.grant_state(&"moon", &"summon", 2)
	return tr.to_jsonl()
