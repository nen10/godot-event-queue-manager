extends RefCounted
## EQM-123: declaration-driven target expansion, effect transformations, and
## provenance-chain carry on OPERATION causation.

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation = preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQRelationGraph = preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")

const GOLDEN_CASE := "expansion_transform"
const GOLDEN_PATH := "res://tests/golden/expansion_transform.trace.jsonl"


static func run(t) -> void:
	_test_view_invariant_without_declarations(t)
	_test_expansion_loop_budget_cutoff(t)
	_test_expansion_multi_rule_union(t)
	_test_expansion_no_relations_no_trace(t)
	_test_retarget_meta_reach_constraints(t)
	_test_retarget_stage_index_argument(t)
	_test_state_inv_transform(t)
	_test_transform_multiround_and_limit(t)
	_test_provenance_inheritance_two_step_operation(t)
	_golden(t)


static func _rr(actors: Array) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for a in actors:
		rr.runtime.register_actor(a)
	return rr


static func _def(kind: int, delay: int = 0) -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = kind
	d.delay = delay
	return d


static func _test_view_invariant_without_declarations(t) -> void:
	var rr := _rr([&"hero"])
	var seen: Array[Dictionary] = []
	rr.runtime.register_effect(&"capture", func(view: Dictionary) -> Array:
		seen.append(view.duplicate(true))
		return []
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"capture"
	d.meta_level = 4
	d.tags = [&"plain"]
	var r := EQReservation.new(&"hero", d)
	r.target_id = &"moon"
	rr.submit(r)
	var got := rr.resolve_next()
	t.ok(got != null, "effect-only reservation resolves")
	t.eq(seen.size(), 1, "capture effect receives one view")
	var view: Dictionary = seen[0]
	t.ok(not view.has("targets"), "no expansion declarations => view has no targets key")
	t.ok(not view.has("provenance"), "no declaration + empty provenance => view has no provenance key")
	t.eq(view.get("meta_level", -1), 4, "meta_level is carried into the view")
	t.eq(view.get("state", &""), &"", "empty state_name does not add state to the view")


## Two rules matching one action (multi-tag) UNION their expansions in the
## deterministic rule order — the second rule must not overwrite the first.
static func _test_expansion_multi_rule_union(t) -> void:
	var rr := _rr([&"hero"])
	var rg := EQRelationGraph.new()
	rg.declare_relation_type({"name": &"summon", "structure": EQRelationGraph.Structure.TREE})
	rg.declare_relation_type({"name": &"analysis", "structure": EQRelationGraph.Structure.GRAPH})
	rg.bind(&"summon", &"moon", &"star")
	rg.bind(&"analysis", &"star", &"scholar")
	rr.relations = rg
	t.ok(rr.declare_expansion_rule({"relation_type": &"summon", "effect_tag": &"損害", "hop_cost": 1, "budget": 1}), "rule 1 declared")
	t.ok(rr.declare_expansion_rule({"relation_type": &"analysis", "effect_tag": &"波及", "hop_cost": 1, "budget": 1}), "rule 2 declared")
	var seen: Array[Dictionary] = []
	rr.runtime.register_effect(&"capture", func(view: Dictionary) -> Array:
		seen.append(view.duplicate(true))
		return []
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"capture"
	d.tags = [&"損害", &"波及"]
	var r := EQReservation.new(&"hero", d)
	r.target_id = &"star"
	rr.submit(r)
	rr.resolve_next()
	t.eq(seen.size(), 1, "one view captured")
	var targets: Array = seen[0].get("targets", [])
	t.eq(targets.size(), 3, "union keeps both rules' expansions")
	t.eq(String(targets[0]), "star", "origin stays first")
	t.ok(targets.has(&"moon") and targets.has(&"scholar"), "both relation types contributed")


## A matching rule whose target has no relations expands nothing — and must
## trace nothing (regression: the targets_expanded record slipped outside the
## expanded-size guard and fired per matching rule).
static func _test_expansion_no_relations_no_trace(t) -> void:
	var rr := _rr([&"hero"])
	var rg := EQRelationGraph.new()
	rg.declare_relation_type({"name": &"summon", "structure": EQRelationGraph.Structure.TREE})
	rr.relations = rg
	t.ok(rr.declare_expansion_rule({"relation_type": &"summon", "effect_tag": &"損害", "hop_cost": 1, "budget": 2}), "rule declared")
	rr.runtime.register_effect(&"noop", func(_v: Dictionary) -> Array: return [])
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"noop"
	d.tags = [&"損害"]
	var r := EQReservation.new(&"hero", d)
	r.target_id = &"loner"
	rr.submit(r)
	rr.resolve_next()
	t.ok(not ('"kind":"targets_expanded"' in rr.runtime.trace_jsonl()), "no expansion => no targets_expanded record")


static func _test_expansion_loop_budget_cutoff(t) -> void:
	var rr := _rr([&"hero"])
	var rg := EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"summon",
		"structure": EQRelationGraph.Structure.GRAPH,
	})
	rg.bind(&"summon", &"moon", &"star")
	rg.bind(&"summon", &"star", &"moon")
	rr.relations = rg
	var rule_ok := rr.declare_expansion_rule({
		"relation_type": &"summon",
		"effect_tag": &"burst",
		"hop_cost": 1,
		"budget": 3,
	})
	t.ok(rule_ok, "declaring expansion rule succeeds")
	var seen: Array[Dictionary] = []
	rr.runtime.register_effect(&"capture", func(view: Dictionary) -> Array:
		seen.append(view.duplicate(true))
		return []
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"capture"
	d.tags = [&"burst"]
	var r := EQReservation.new(&"hero", d)
	r.target_id = &"moon"
	rr.submit(r)
	rr.resolve_next()
	t.ok(not seen.is_empty(), "effect saw transformed reservation view")
	var view: Dictionary = seen[0]
	var targets: Array[StringName] = []
	if view.has("targets") and view["targets"] is Array:
		targets = view["targets"]
	t.eq(targets.size(), 2, "loop-aware expansion with budget=3 reaches each actor once")
	t.eq(targets[0], &"moon", "target expansion keeps origin as first")
	t.eq(targets[1], &"star", "deterministic expansion follows first discovered relation")
	t.ok(rr.runtime.trace_jsonl().find("\"kind\":\"targets_expanded\"") >= 0, "targets_expanded trace is emitted")


static func _run_retarget_case(t, rr: EQReservationRuntime, transform: Dictionary, provenance: Array[Dictionary]) -> StringName:
	var seen: Array[Dictionary] = []
	rr.register_transform(transform)
	rr.runtime.register_effect(&"capture", func(view: Dictionary) -> Array:
		seen.append(view.duplicate(true))
		return []
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"capture"
	d.tags = [&"relink"]
	var r := EQReservation.new(&"caster", d)
	r.target_id = &"final"
	r.provenance = provenance
	rr.submit(r)
	rr.resolve_next()
	t.eq(seen.size(), 1, "retarget transform test captured exactly one transformed view")
	return seen[0].get("target", &"") as StringName


static func _test_retarget_meta_reach_constraints(t) -> void:
	var rr1 := _rr([&"caster"])
	var reached := _run_retarget_case(t, rr1, {
		"name": &"root_reachable",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": "root"},
		"meta_level": 1,
		"priority": 0,
	}, [
		{"actor": &"moon", "event_id": 11, "meta_level": 0},
		{"actor": &"direct", "event_id": 12, "meta_level": 3},
	])
	t.eq(reached, &"moon", "root stage reaches the farthest valid segment (meta equality included)")

	var rr2 := _rr([&"caster"])
	var unchanged := _run_retarget_case(t, rr2, {
		"name": &"root_unreachable",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": "root"},
		"meta_level": 0,
		"priority": 0,
	}, [
		{"actor": &"moon", "event_id": 21, "meta_level": 2},
		{"actor": &"direct", "event_id": 22, "meta_level": 3},
	])
	t.eq(unchanged, &"final", "root stage with low meta_level leaves target unchanged")

	var rr3 := _rr([&"caster"])
	var direct_hit := _run_retarget_case(t, rr3, {
		"name": &"direct_equal",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": "direct"},
		"meta_level": 2,
		"priority": 0,
	}, [
		{"actor": &"moon", "event_id": 31, "meta_level": 0},
		{"actor": &"direct", "event_id": 32, "meta_level": 2},
	])
	t.eq(direct_hit, &"direct", "direct stage accepts equal meta_level boundary")


static func _test_retarget_stage_index_argument(t) -> void:
	var rr1 := _rr([&"caster"])
	var idx_direct := _run_retarget_case(t, rr1, {
		"name": &"int_stage_direct",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": 1},
		"meta_level": 2,
		"priority": 0,
	}, [
		{"actor": &"root", "event_id": 41, "meta_level": 3},
		{"actor": &"direct", "event_id": 42, "meta_level": 1},
	])
	t.eq(idx_direct, &"direct", "int stage 1 reaches direct")

	var rr2 := _rr([&"caster"])
	var idx_root := _run_retarget_case(t, rr2, {
		"name": &"int_stage_root",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": 0},
		"meta_level": 2,
		"priority": 0,
	}, [
		{"actor": &"root", "event_id": 43, "meta_level": 3},
		{"actor": &"direct", "event_id": 44, "meta_level": 1},
	])
	t.eq(idx_root, &"final", "int stage 0 keeps no-op when root meta is higher than transform meta")

	var rr3 := _rr([&"caster"])
	var idx_oob := _run_retarget_case(t, rr3, {
		"name": &"int_stage_oob",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": 5},
		"meta_level": 99,
		"priority": 0,
	}, [
		{"actor": &"root", "event_id": 45, "meta_level": 3},
		{"actor": &"direct", "event_id": 46, "meta_level": 1},
	])
	t.eq(idx_oob, &"final", "int stage 5 is out-of-range no-op")

	var rr4 := _rr([&"caster"])
	var root_string := _run_retarget_case(t, rr4, {
		"name": &"root_string",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": "root"},
		"meta_level": 2,
		"priority": 0,
	}, [
		{"actor": &"root", "event_id": 47, "meta_level": 3},
		{"actor": &"direct", "event_id": 48, "meta_level": 1},
	])
	t.eq(root_string, &"direct", "root stage string semantics unchanged")

	var rr5 := _rr([&"caster"])
	var direct_string := _run_retarget_case(t, rr5, {
		"name": &"direct_string",
		"match_tags": [&"relink"],
		"kind": "retarget",
		"params": {"stage": "direct"},
		"meta_level": 2,
		"priority": 0,
	}, [
		{"actor": &"root", "event_id": 49, "meta_level": 3},
		{"actor": &"direct", "event_id": 50, "meta_level": 1},
	])
	t.eq(direct_string, &"direct", "direct stage string semantics unchanged")


static func _test_state_inv_transform(t) -> void:
	var rr := _rr([&"hero"])
	var seen: Array[Dictionary] = []
	var reg_ok := rr.register_transform({
		"name": &"damage_toggle",
		"match_tags": [&"stateful"],
		"kind": "state_inv",
		"params": {"pair": [&"healthy", &"injured"]},
		"meta_level": 0,
		"priority": 0,
	})
	t.eq(reg_ok, true, "state_inv transform registration succeeds")
	t.ok(rr.runtime.faults.is_empty(), "state_inv transform registration has no runtime faults")
	rr.runtime.register_effect(&"capture", func(view: Dictionary) -> Array:
		seen.append(view.duplicate(true))
		return []
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"capture"
	d.state_name = &"healthy"
	d.tags = [&"stateful"]
	var r := EQReservation.new(&"hero", d)
	t.eq(rr._matching_transforms(r).size(), 1, "stateful transform is selected for matching declaration")
	var raw_view := rr._view_of(r)
	t.eq(raw_view.get("state", &""), &"healthy", "baseline view carries state_name as state")
	t.eq(raw_view.has("state"), true, "baseline view exposes state field")
	var state_probe := {"state": &"healthy"}
	var probe_transform := {"params": {"pair": [&"healthy", &"injured"]}}
	t.eq(state_probe.has("state"), true, "direct probe has state field")
	var state_probe_out: Variant = rr._apply_state_transform(state_probe, probe_transform)
	t.eq(state_probe_out != null, true, "state_inv transform path executes for direct probe")
	t.eq(state_probe_out.get("state", &""), &"injured", "state_inv transform probe rewrites healthy to injured")
	var transformed := rr._apply_effect_transforms(r, rr._apply_target_expansion(r, raw_view.duplicate(true)))
	t.eq(transformed.get("state", &""), &"injured", "state_inv transforms directly mutate effect view")
	t.ok(rr.runtime.faults.is_empty(), "state_inv converges without relying on the round guard")
	rr.submit(r)
	rr.resolve_next()
	t.eq(seen.size(), 1, "state inversion transform emitted one transformed view")
	t.eq(seen[0].get("state", &""), &"injured", "resolved view keeps the one-shot inverse")
	t.ok(rr.runtime.faults.is_empty(), "state inversion resolution publishes no transform-round fault")
	var view: Dictionary = seen[0]
	t.eq(view.get("state", &""), &"injured", "state_inv transform rewrites paired state")


static func _test_transform_multiround_and_limit(t) -> void:
	var rr := _rr([&"hero"])
	var reg_ok_a := rr.register_transform({
		"name": &"state_progress_first",
		"match_tags": [&"rounder"],
		"kind": "state_inv",
		"params": {"pair": [&"a", &"b"]},
		"meta_level": 10,
		"priority": 1,
	})
	t.eq(reg_ok_a, true, "first state_inv transform registration succeeds")
	var reg_ok_b := rr.register_transform({
		"name": &"state_progress_second",
		"match_tags": [&"rounder"],
		"kind": "state_inv",
		"params": {"pair": [&"b", &"c"]},
		"meta_level": 9,
		"priority": 0,
	})
	t.eq(reg_ok_b, true, "second state_inv transform registration succeeds")
	t.ok(rr.runtime.faults.is_empty(), "state_inv transform registrations have no runtime faults")
	var seen: Array[Dictionary] = []
	rr.runtime.register_effect(&"capture_rounder", func(view: Dictionary) -> Array:
		seen.append(view.duplicate(true))
		return []
	)
	var d1 := _def(EQActionDefinition.Kind.IMMEDIATE)
	d1.effect_name = &"capture_rounder"
	d1.state_name = &"a"
	d1.tags = [&"rounder"]
	var r1 := EQReservation.new(&"hero", d1)
	t.eq(rr._matching_transforms(r1).size(), 2, "rounder transforms both selected for matching declarations")
	var raw_view := rr._view_of(r1)
	var transformed := rr._apply_effect_transforms(r1, rr._apply_target_expansion(r1, raw_view.duplicate(true)))
	t.eq(transformed.get("state", &""), &"c", "rounder transforms directly mutate effect view")
	rr.submit(r1)
	rr.resolve_next()
	var v: Dictionary = seen[0]
	t.eq(seen.size(), 1, "multiround transform scenario captured one final view")
	t.eq(v.get("state", &""), &"c", "two-state_inv declarations required multiple rounds: a -> b -> c")

	var rr_tight := _rr([&"hero"])
	var reg_ok_loop := rr_tight.register_transform({
		"name": &"state_loop",
		"match_tags": [&"toggle"],
		"kind": "state_inv",
		"params": {"pair": [&"left", &"right"]},
		"meta_level": 0,
		"priority": 0,
	})
	t.eq(reg_ok_loop, true, "looping state_inv transform registration succeeds")
	t.ok(rr_tight.runtime.faults.is_empty(), "looping transform registration has no runtime faults")
	rr_tight.runtime.register_effect(&"toggle", func(_v: Dictionary) -> Array:
		return []
	)
	var d2 := _def(EQActionDefinition.Kind.IMMEDIATE)
	d2.effect_name = &"toggle"
	d2.state_name = &"left"
	d2.tags = [&"toggle"]
	rr_tight.submit(EQReservation.new(&"hero", d2))
	rr_tight.resolve_next()
	t.ok(rr_tight.runtime.faults.is_empty(), "one-shot state inversion converges before the round guard")

	var rr_zero_round := _rr([&"hero"])
	rr_zero_round.max_transform_rounds = 0
	rr_zero_round.register_transform({
		"name": &"state_guard_probe",
		"match_tags": [&"toggle"],
		"kind": "state_inv",
		"params": {"pair": [&"left", &"right"]},
		"meta_level": 0,
		"priority": 0,
	})
	rr_zero_round.runtime.register_effect(&"toggle", func(_v: Dictionary) -> Array:
		return []
	)
	rr_zero_round.submit(EQReservation.new(&"hero", d2))
	rr_zero_round.resolve_next()
	t.ok(rr_zero_round.runtime.faults.size() > 0, "zero transform-round budget records a fault")
	var last: Dictionary = rr_zero_round.runtime.faults.back()
	t.eq(last.get("code", ""), EQError.CONDITION_LINE_UNKNOWN, "round-limit fault is reported through a stable error code")


static func _test_provenance_inheritance_two_step_operation(t) -> void:
	var rr := _rr([&"root", &"mid", &"victim"])
	var op1_event_box := {"value": -1}
	var op2 := EQActionDefinition.new()
	op2.kind = EQActionDefinition.Kind.OPERATION
	op2.operation_target_tag = &"counter"
	op2.meta_level = 2
	var op2_res := EQReservation.new(&"mid", op2)
	op2_res.target_id = &"victim"
	var op2_event_id_box := {"value": -1}

	var op1 := EQActionDefinition.new()
	op1.kind = EQActionDefinition.Kind.OPERATION
	op1.operation_target_tag = &"counter_seed"
	op1.meta_level = 9
	op1.effect_name = &"launch_mid"
	rr.runtime.register_effect(&"launch_mid", func(_view: Dictionary) -> Array:
		var root_event_id: int = int(op1_event_box["value"])
		op2_res.provenance = [{
			"actor": &"root",
			"event_id": root_event_id,
			"meta_level": int(op1.meta_level),
		}]
		op2_event_id_box["value"] = rr.submit(op2_res)
		return []
	)
	var r1 := EQReservation.new(&"root", op1)
	r1.target_id = &"mid"
	op1_event_box["value"] = rr.submit(r1)
	t.eq(op1_event_box["value"] > 0, true, "first OPERATION submit returns a concrete event_id")
	var res1 := rr.resolve_next()
	t.eq(res1, r1, "first OPERATION resolves and seeds provenance for the next one")
	t.eq(res1.event_id, op1_event_box["value"], "first OPERATION event id is propagated to resolve result")
	# second OPERATION is scheduled from the first's effect and then resolves,
	# creating a caused reservation on the target.
	var res2 := rr.resolve_next()
	t.ok(res2 != null and res2.actor_id == &"mid", "second OPERATION resolves from the cause-chain")
	t.ok(op2_event_id_box["value"] > 0, "second OPERATION submit returns a concrete event_id")
	t.eq(op2_event_id_box["value"], res2.event_id, "second OPERATION event_id propagates to resolved second OPERATION")
	var caused := rr.armed_for(&"victim")
	t.eq(caused.size(), 1, "second OPERATION caused one REACTION_PREPARATION reservation")
	t.eq(caused[0].provenance.size(), 2, "caused reservation carries full 2-step provenance chain")
	t.eq(caused[0].provenance[0].get("actor", &""), &"root", "first provenance step is root")
	t.eq(caused[0].provenance[1].get("actor", &""), &"mid", "second provenance step is intermediate OPERATION actor")
	t.eq(caused[0].provenance[0].get("event_id", -1), op1_event_box["value"], "first provenance step retains root event_id")
	t.eq(caused[0].provenance[1].get("event_id", -1), res2.event_id, "second provenance step retains second event_id")
	t.eq(caused[0].provenance[1].get("meta_level", -1), int(op2.meta_level), "second provenance step retains operation meta_level")


static func _golden(t) -> void:
	var jsonl := _build_golden_scenario_trace()
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		_write_golden(t, jsonl)
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via ./tools/test.sh --update-golden %s)" % [GOLDEN_PATH, GOLDEN_CASE])
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		_dump_actual(jsonl)
	t.eq(jsonl, want, "golden scenario trace matches expansion_transform (re-baseline: ./tools/test.sh --update-golden %s)" % GOLDEN_CASE)


static func _build_golden_scenario_trace() -> String:
	var rr := _rr([&"hero", &"moon", &"star"])
	var rg := EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"summon",
		"structure": EQRelationGraph.Structure.GRAPH,
	})
	rg.bind(&"summon", &"moon", &"star")
	rr.relations = rg

	rr.declare_expansion_rule({
		"relation_type": &"summon",
		"effect_tag": &"damage",
		"hop_cost": 1,
		"budget": 2,
	})
	rr.register_transform({
		"name": &"retarget_to_source",
		"match_tags": [&"damage"],
		"kind": "retarget",
		"params": {"stage": "direct"},
		"meta_level": 0,
		"priority": 0,
	})
	rr.runtime.register_effect(&"damage", func(_view: Dictionary) -> Array:
		return []
	)

	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"damage"
	d.tags = [&"damage"]
	var r := EQReservation.new(&"hero", d)
	r.target_id = &"star"
	rr.submit(r)
	rr.resolve_next()
	return rr.runtime.trace_jsonl()


static func _write_golden(t, jsonl: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	if f == null:
		t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
		return
	f.store_string(jsonl)
	f.close()
	t.ok(true, "golden re-baselined for %s via --update-golden" % GOLDEN_CASE)


static func _dump_actual(jsonl: String) -> void:
	var out := OS.get_environment("EQ_RUN_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out + "/traces")
	var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
	if f != null:
		f.store_string(jsonl)
		f.close()
