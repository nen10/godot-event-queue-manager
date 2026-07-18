extends RefCounted
## EQM-122: relation graph backend contract tests.

const EQRelationGraph = preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")
const EQReservationRuntime = preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation = preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition = preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQTrace = preload("res://addons/event_queue_manager/runtime/eq_trace.gd")
const EQConditionSpec = preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")


static func run(t) -> void:
	_test_declare_type_redeclaration_and_invalid(t)
	_test_bind_dissolve_invert_and_trace(t)
	_test_failed_tree_invert_restores_adjacency(t)
	_test_adjacency_query_and_expand_order(t)
	_test_duplicate_relation_id_restore_reindexes(t)
	_test_serial_rebound_chain(t)
	_test_invalidate_actor(t)
	_test_maintenance(t)
	_test_step_tick_relation_maintenance_auto_default_sweep(t)
	_test_step_tick_relation_maintenance_auto_custom_sweep(t)
	_test_step_tick_without_relations_keeps_behavior(t)
	_test_roundtrip(t)
	_test_lunar_stellar_acceptance_example(t)
	_test_reservation_runtime_wiring(t)


static func _rr(actors: Array) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for actor in actors:
		rr.runtime.register_actor(actor)
	return rr


static func _def(kind: int, delay: int = 0) -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = kind
	d.delay = delay
	return d


## EQM-122 wiring: an attached relation graph is swept by the normal-path
## departure (SEM §13.1 — invalidate_actor dissolves incident relations
## through the declared on_dissolve rules; never a silent removal).
static func _test_reservation_runtime_wiring(t) -> void:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"moon")
	rr.runtime.register_actor(&"star")
	var rg = EQRelationGraph.new()
	rr.relations = rg
	rg.declare_relation_type({"name": &"summon", "structure": EQRelationGraph.Structure.TREE})
	var rel = rg.bind(&"summon", &"moon", &"star")
	t.ok(rel != &"", "relation bound before departure")
	rr.invalidate_actor(&"star")
	t.ok(rg.relation(rel).is_empty(), "departure dissolves incident relations through the graph")
	t.eq(rg.relations_of(&"moon").size(), 0, "no dangling relation on the surviving endpoint")


static func _test_declare_type_redeclaration_and_invalid(t) -> void:
	var rg = EQRelationGraph.new()
	t.ok(rg.declare_relation_type({
		"name": &"追跡",
		"category": &"tracking",
		"inverse": &"復讐",
		"structure": EQRelationGraph.Structure.TREE,
		"sweep": &"eqm.sweep.primary_threshold",
		"on_dissolve": EQRelationGraph.Dissolve.NONE,
		"maintenance": {
			"type": EQConditionSpec.Type.LINE_THRESHOLD,
			"line_id": &"eqm.line.primary",
			"threshold": 10,
			"comparison": EQConditionSpec.Comparison.GE,
			"relative": false,
		},
	}), "valid declaration registers")
	var declared = rg.to_dict()
	t.eq((declared.get("relation_types", []) as Array).size(), 1, "one declaration")
	t.eq((declared.get("relation_types", [])[0] as Dictionary).get("category", ""), "tracking", "category is preserved")

	t.ok(rg.declare_relation_type({
		"name": &"追跡",
		"category": &"追跡",
		"inverse": &"復讐",
		"structure": EQRelationGraph.Structure.GRAPH,
		"on_dissolve": EQRelationGraph.Dissolve.SERIAL_SUTURE,
	}), "same name declaration replaces")
	declared = rg.to_dict()
	t.eq((declared.get("relation_types", [])[0] as Dictionary).get("structure", -1), EQRelationGraph.Structure.GRAPH, "replacement updates structure")

	t.ok(rg.declare_relation_type({"name": &"", "structure": EQRelationGraph.Structure.TREE}) == false, "empty type name faults")
	t.ok(rg.declare_relation_type({"name": &"bad", "structure": 99}) == false, "unknown structure enum faults")
	t.ok(rg.declare_relation_type({"name": &"bad2", "structure": EQRelationGraph.Structure.TREE, "on_dissolve": 9}) == false, "unknown on_dissolve enum faults")
	t.ok(rg.faults.size() >= 3, "invalid declarations produce faults")


static func _test_bind_dissolve_invert_and_trace(t) -> void:
	var tr = EQTrace.new()
	var rg = EQRelationGraph.new(tr)
	rg.declare_relation_type({
		"name": &"樹",
		"structure": EQRelationGraph.Structure.TREE,
		"on_dissolve": EQRelationGraph.Dissolve.NONE,
	})
	rg.declare_relation_type({
		"name": &"追跡",
		"inverse": &"復讐",
		"on_dissolve": EQRelationGraph.Dissolve.NONE,
	})
	rg.declare_relation_type({
		"name": &"復讐",
		"inverse": &"追跡",
		"on_dissolve": EQRelationGraph.Dissolve.NONE,
	})
	rg.declare_relation_type({
		"name": &"相互",
		"structure": EQRelationGraph.Structure.GRAPH,
	})

	var tree_id := rg.bind(&"樹", &"月", &"星")
	t.eq(String(tree_id), "eqm.rel.1", "first relation gets deterministic id")
	t.ok(rg.bind(&"樹", &"太陽", &"星") == &"", "tree blocks multiple parents")
	var id_graph_1 = rg.bind(&"相互", &"月", &"星")
	var id_graph_2 = rg.bind(&"相互", &"星", &"月")
	t.ok(id_graph_1 != &"" and id_graph_2 != &"", "GRAPH allows back-edge")

	var inv_id = rg.bind(&"追跡", &"月", &"星")
	t.ok(rg.invert(inv_id), "invert succeeds")
	var rel = rg.relation(inv_id)
	t.eq(rel.get("type", &""), &"復讐", "invert changes type")
	t.eq(rel.get("from_actor", &""), &"星", "invert swaps from")
	t.eq(rel.get("to_actor", &""), &"月", "invert swaps to")

	var dissolve_ok = rg.dissolve(inv_id)
	t.eq(dissolve_ok, true, "dissolve after invert returns true")

	var rows = _json_rows(tr.to_jsonl())
	t.ok(_has_trace(rows, "relation_bound", &"eqm.rel.1"), "relation_bound is recorded")
	t.ok(_has_trace(rows, "relation_inverted", String(inv_id)), "relation_inverted is recorded")
	t.ok(_has_trace(rows, "relation_dissolved", String(inv_id)), "relation_dissolved is recorded")


static func _test_failed_tree_invert_restores_adjacency(t) -> void:
	var rg = EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"forward",
		"inverse": &"reverse",
		"structure": EQRelationGraph.Structure.TREE,
	})
	rg.declare_relation_type({
		"name": &"reverse",
		"inverse": &"forward",
		"structure": EQRelationGraph.Structure.TREE,
	})
	var existing_parent = rg.bind(&"reverse", &"X", &"A")
	var original = rg.bind(&"forward", &"A", &"B")

	t.ok(not rg.invert(original), "TREE inverse rejects a second reverse parent")
	var restored = rg.relation(original)
	t.eq(restored.get("type", &""), &"forward", "failed invert restores original relation type")
	t.eq(restored.get("from_actor", &""), &"A", "failed invert restores original from endpoint")
	t.eq(restored.get("to_actor", &""), &"B", "failed invert restores original to endpoint")
	t.eq(
		_relation_id_strings(rg.relations_of(&"A")),
		[String(existing_parent), String(original)],
		"failed invert reindexes the original relation beside the blocking parent",
	)
	t.eq(
		_relation_id_strings(rg.relations_of(&"B")),
		[String(original)],
		"failed invert restores adjacency at the original target",
	)
	t.eq(rg.invalidate_actor(&"B"), 1, "restored target adjacency remains usable by invalidation")
	t.ok(rg.relation(original).is_empty(), "restored original relation is dissolved exactly once")


static func _test_adjacency_query_and_expand_order(t) -> void:
	var rg = EQRelationGraph.new()
	rg.declare_relation_type({"name": &"link", "structure": EQRelationGraph.Structure.GRAPH})
	rg.declare_relation_type({"name": &"other", "structure": EQRelationGraph.Structure.GRAPH})

	rg.bind(&"link", &"unrelated.0", &"unrelated.1")
	var id2 = rg.bind(&"link", &"hub", &"a")
	for i in range(7):
		rg.bind(
			&"link",
			StringName("unrelated.%d.left" % i),
			StringName("unrelated.%d.right" % i),
		)
	var id10 = rg.bind(&"link", &"hub", &"b")
	var id11 = rg.bind(&"link", &"hub", &"hub")
	var id12 = rg.bind(&"other", &"hub", &"ignored")

	var expected_ids: Array[String] = [String(id2), String(id10), String(id11), String(id12)]
	expected_ids.sort()
	t.eq(
		_relation_id_strings(rg.relations_of(&"hub")),
		expected_ids,
		"relations_of keeps lexicographic relation-id order beyond single digits",
	)
	t.eq(
		(rg._actor_relations["hub"] as Array).count(id11),
		1,
		"a self-loop occupies one incident adjacency slot",
	)

	var projected: Array = rg.relations_of(&"hub")
	projected[0]["from_actor"] = &"mutated"
	projected.clear()
	t.eq(
		_relation_id_strings(rg.relations_of(&"hub")),
		expected_ids,
		"relations_of returns fresh arrays and deep-copied payloads",
	)
	t.eq(
		rg.expand(&"hub", &"link", 1, 1),
		[&"hub", &"b", &"a"],
		"adjacency expansion preserves lexicographic relation-id discovery order",
	)

	var rebuilt = EQRelationGraph.new()
	rebuilt.restore(rg.to_dict())
	t.eq(
		_relation_id_strings(rebuilt.relations_of(&"hub")),
		expected_ids,
		"restore rebuilds identical sorted actor adjacency",
	)
	t.eq(
		rebuilt.expand(&"hub", &"link", 1, 1),
		[&"hub", &"b", &"a"],
		"restored adjacency keeps exact bounded expansion order",
	)


static func _test_duplicate_relation_id_restore_reindexes(t) -> void:
	var rg = EQRelationGraph.new()
	rg.restore({
		"relation_types": [{"name": &"link", "structure": EQRelationGraph.Structure.GRAPH}],
		"relations": [
			{"relation_id": &"eqm.rel.7", "type": &"link", "from": &"A", "to": &"B"},
			{"relation_id": &"eqm.rel.8", "type": &"link", "from": &"C", "to": &"E"},
			{"relation_id": &"eqm.rel.7", "type": &"link", "from": &"C", "to": &"D"},
		],
		"relation_seq": 8,
	})

	t.eq(rg.relation(&"eqm.rel.7").get("from_actor", &""), &"C", "duplicate id remains canonical last-entry-wins")
	t.ok(rg.relations_of(&"A").is_empty(), "replaced relation leaves no stale first endpoint adjacency")
	t.ok(rg.relations_of(&"B").is_empty(), "replaced relation leaves no stale second endpoint adjacency")
	t.eq(
		_relation_id_strings(rg.relations_of(&"C")),
		["eqm.rel.7", "eqm.rel.8"],
		"last endpoints own each restored relation id exactly once",
	)
	t.eq(rg.invalidate_actor(&"A"), 0, "stale endpoint cannot invalidate replacement relation")
	t.ok(not rg.relation(&"eqm.rel.7").is_empty(), "replacement survives stale-endpoint invalidation")
	t.eq(rg.invalidate_actor(&"C"), 2, "canonical endpoint invalidates both incident relations")
	t.ok(rg.relation_ids().is_empty(), "canonical invalidation leaves no dangling relation")

	var tree = EQRelationGraph.new()
	tree.restore({
		"relation_types": [{"name": &"tree", "structure": EQRelationGraph.Structure.TREE}],
		"relations": [
			{"relation_id": &"eqm.rel.7", "type": &"tree", "from": &"A", "to": &"B"},
			{"relation_id": &"eqm.rel.7", "type": &"tree", "from": &"C", "to": &"B"},
		],
		"relation_seq": 7,
	})
	t.eq(tree.relation(&"eqm.rel.7").get("from_actor", &""), &"C", "TREE duplicate id excludes its old payload from parent validation")
	t.ok(tree.relations_of(&"A").is_empty(), "TREE replacement removes its old source adjacency")
	t.eq(
		_relation_id_strings(tree.relations_of(&"B")),
		["eqm.rel.7"],
		"TREE replacement retains one canonical target adjacency",
	)

	var blocked = EQRelationGraph.new()
	blocked.restore({
		"relation_types": [{"name": &"tree", "structure": EQRelationGraph.Structure.TREE}],
		"relations": [
			{"relation_id": &"eqm.rel.7", "type": &"tree", "from": &"A", "to": &"C"},
			{"relation_id": &"eqm.rel.8", "type": &"tree", "from": &"X", "to": &"B"},
			{"relation_id": &"eqm.rel.7", "type": &"tree", "from": &"D", "to": &"B"},
		],
		"relation_seq": 8,
	})
	t.eq(blocked.relation(&"eqm.rel.7").get("to_actor", &""), &"C", "a different TREE parent still blocks duplicate-id replacement")
	t.eq(blocked.faults.size(), 1, "blocked TREE replacement records the existing stable constraint fault")


static func _test_serial_rebound_chain(t) -> void:
	var tr = EQTrace.new()
	var rg = EQRelationGraph.new(tr)
	rg.declare_relation_type({
		"name": &"鎖",
		"structure": EQRelationGraph.Structure.TREE,
		"on_dissolve": EQRelationGraph.Dissolve.SERIAL_SUTURE,
	})

	var a = rg.bind(&"鎖", &"A", &"B")
	var b = rg.bind(&"鎖", &"B", &"C")
	t.ok(rg.dissolve(a), "dissolve middle-like edge")
	var rows = _json_rows(tr.to_jsonl())
	var rebound_id = _trace_field(rows, "relation_rebound", "via", String(a), "new_relation")
	t.ok(rebound_id != &"", "serial chain creates rebound")
	var rel = rg.relation(rebound_id)
	t.ok(rel.get("type", &"") == &"鎖", "rebound preserves type")
	t.eq(rel.get("from_actor", &""), &"A", "rebound starts at former chain start")
	t.eq(rel.get("to_actor", &""), &"C", "rebound ends at former chain end")

	var x = rg.bind(&"鎖", &"X", &"Y")
	t.ok(rg.dissolve(x), "endpoint-only relation dissolves")
	rows = _json_rows(tr.to_jsonl())
	t.eq(_count_kind(rows, "relation_rebound"), 1, "no additional rebound on endpoint-only dissolve")


static func _test_invalidate_actor(t) -> void:
	var tr = EQTrace.new()
	var rg = EQRelationGraph.new(tr)
	rg.declare_relation_type({
		"name": &"追跡",
		"structure": EQRelationGraph.Structure.TREE,
		"on_dissolve": EQRelationGraph.Dissolve.SERIAL_SUTURE,
	})
	var x = rg.bind(&"追跡", &"X", &"A")
	var a = rg.bind(&"追跡", &"A", &"B")
	var b = rg.bind(&"追跡", &"B", &"Y")

	t.eq(rg.invalidate_actor(&"B"), 2, "invalidate_actor dissolves endpoint relations")
	var rows = _json_rows(tr.to_jsonl())
	var expected_dissolved: Array[String] = [String(a), String(b)]
	expected_dissolved.sort()
	t.eq(
		_trace_relation_ids(rows, "relation_dissolved"),
		expected_dissolved,
		"invalidate_actor dissolves the original incident snapshot in relation-id order",
	)
	t.eq(_count_kind(rows, "relation_dissolved"), 2, "invalidate_actor emits dissolve trace")
	t.eq(_count_with_context(rows, "relation_dissolved", "cause", &"actor_removed"), 2, "invalidate_actor uses actor_removed cause")
	t.eq(_count_kind(rows, "relation_rebound"), 1, "invalidate_actor may apply serial rebound")
	t.ok(rg.relations_of(&"B").is_empty(), "actor B has no relations afterwards")
	var rebound_id = _trace_field(rows, "relation_rebound", "via", String(a), "new_relation")
	var rebound = rg.relation(rebound_id)
	t.eq(rebound.get("from_actor", &""), &"X", "serial rebound still starts before invalidated actor")
	t.eq(rebound.get("to_actor", &""), &"Y", "serial rebound still ends after invalidated actor")
	t.ok(not rg.relation(x).is_empty(), "unrelated original chain segment survives invalidation")


static func _test_maintenance(t) -> void:
	var tr = EQTrace.new()
	var rg = EQRelationGraph.new(tr)
	rg.declare_relation_type({
		"name": &"寿命",
		"structure": EQRelationGraph.Structure.TREE,
		"sweep": &"eqm.sweep.primary_threshold",
		"maintenance": {
			"type": EQConditionSpec.Type.LINE_THRESHOLD,
			"line_id": &"eqm.line.primary",
			"threshold": 5,
			"comparison": EQConditionSpec.Comparison.LE,
		},
	})
	rg.declare_relation_type({
		"name": &"再生",
		"structure": EQRelationGraph.Structure.TREE,
		"sweep": &"eqm.sweep.primary_threshold",
		"maintenance": {
			"type": EQConditionSpec.Type.NAMED_PREDICATE,
			"predicate_name": &"is_hot",
		},
	})
	rg.declare_relation_type({
		"name": &"未登録",
		"structure": EQRelationGraph.Structure.TREE,
		"sweep": &"eqm.sweep.primary_threshold",
		"maintenance": {
			"type": EQConditionSpec.Type.NAMED_PREDICATE,
			"predicate_name": &"missing",
		},
	})

	var r1 = rg.bind(&"寿命", &"月", &"星")
	var r2 = rg.bind(&"再生", &"月", &"星")
	var r3 = rg.bind(&"未登録", &"月", &"星")

	var resolved = rg.run_maintenance(&"eqm.sweep.primary_threshold", {"lines": {&"eqm.line.primary": 9}, "view": {}}, {})
	t.eq(resolved, 1, "line-threshold with LE and greater-than-threshold dissolves")
	t.ok(rg.relation(r1).is_empty(), "failed line maintenance is dissolved")

	resolved = rg.run_maintenance(&"eqm.sweep.primary_threshold", {"lines": {&"eqm.line.primary": 9}, "view": {}}, {
		"is_hot": func(view): return false,
	})
	t.eq(resolved, 1, "predicate false dissolves relation")
	t.ok(rg.relation(r2).is_empty(), "failed predicate maintenance is dissolved")

	var before_faults: int = rg.faults.size()
	t.eq(rg.run_maintenance(&"eqm.sweep.primary_threshold", {"lines": {&"eqm.line.primary": 9}, "view": {}}, {}), 0, "missing predicate does not dissolve")
	t.ok(rg.faults.size() > before_faults, "missing predicate registers fault")
	t.ok(rg.relation(r3).has("relation_id"), "missing predicate relation remains")

	# Isolated instance: a maintenance-less type under its own sweep must be a
	# clean no-op (regression: a typed-null local raised an engine error and a
	# bogus fault per sweep).
	var rg2 = EQRelationGraph.new()
	rg2.declare_relation_type({
		"name": &"無条件",
		"structure": EQRelationGraph.Structure.TREE,
		"sweep": &"eqm.sweep.primary_threshold",
	})
	var r4 = rg2.bind(&"無条件", &"月", &"星2")
	t.eq(rg2.run_maintenance(&"eqm.sweep.primary_threshold", {"lines": {&"eqm.line.primary": 9}, "view": {}}, {}), 0, "maintenance-less type under its sweep dissolves nothing (regression: typed-null crash)")
	t.eq(rg2.faults.size(), 0, "maintenance-less type records no fault")
	t.ok(rg2.relation(r4).has("relation_id"), "maintenance-less relation survives the sweep")


## Runtime bridge: with a connected relation graph, default-sweep maintenance
## must be auto-driven from step_tick via the runtime helper.
static func _test_step_tick_relation_maintenance_auto_default_sweep(t) -> void:
	var rr := _rr([&"moon", &"star"])
	rr.runtime.register_predicate(&"is_live", func(_view): return false)
	var rg := EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"追跡",
		"structure": EQRelationGraph.Structure.GRAPH,
		"maintenance": {
			"type": EQConditionSpec.Type.NAMED_PREDICATE,
			"predicate_name": &"is_live",
		},
	})
	rr.relations = rg
	var rel := rg.bind(&"追跡", &"moon", &"star")
	rr.step_tick()
	t.ok(rg.relation(rel).is_empty(), "default sweep is automatically run by step_tick")
	t.eq(rg.faults.size(), 0, "missing predicate registration path is not used for runtime-driven default sweep")


## Custom sweep names must be evaluated from step_tick by sweep-rule registration order.
static func _test_step_tick_relation_maintenance_auto_custom_sweep(t) -> void:
	var rr := _rr([&"moon", &"star"])
	rr.runtime.register_predicate(&"allow", func(_view): return false)
	var rg := EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"視界",
		"structure": EQRelationGraph.Structure.GRAPH,
		"sweep": &"turn_start",
		"maintenance": {
			"type": EQConditionSpec.Type.NAMED_PREDICATE,
			"predicate_name": &"allow",
		},
	})
	rr.relations = rg
	var rel := rg.bind(&"視界", &"moon", &"star")
	var called := {"count": 0}
	rr.lines.register_sweep_rule(&"turn_start", func(_actor_id: StringName, _data: Dictionary, _lines) -> void:
		called["count"] += 1
	)
	rr.step_tick()
	t.eq(called["count"], 2, "registered turn_start sweep rule is still executed per actor")
	t.ok(rg.relation(rel).is_empty(), "custom sweep rule name triggers linked relation maintenance")
	t.ok(rg.relation(rel).is_empty(), "custom sweep test does not depend on default sweep")


## No relation graph means step_tick keeps behavior (no maintenance errors, no new effects).
static func _test_step_tick_without_relations_keeps_behavior(t) -> void:
	var rr := _rr([&"moon", &"star"])
	rr.runtime.register_predicate(&"always", func(_view): return false)
	rr.step_tick()
	t.eq(rr.runtime.faults.size(), 0, "step_tick is safe when no relation graph is attached")


static func _test_roundtrip(t) -> void:
	var rg = EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"追跡",
		"category": &"trace",
		"structure": EQRelationGraph.Structure.TREE,
		"on_dissolve": EQRelationGraph.Dissolve.SERIAL_SUTURE,
	})
	rg.declare_relation_type({
		"name": &"解析",
		"structure": EQRelationGraph.Structure.GRAPH,
	})
	var id1 = rg.bind(&"追跡", &"月", &"星")
	var id2 = rg.bind(&"解析", &"月", &"魔")
	var snapshot = rg.to_dict()

	var re = EQRelationGraph.new()
	re.restore(snapshot)
	t.eq(re.to_dict(), snapshot, "to_dict/restore roundtrip")
	var next = re.bind(&"追跡", &"月", &"虎")
	t.eq(String(next), "eqm.rel.3", "relation id sequence continues")


static func _test_lunar_stellar_acceptance_example(t) -> void:
	var rg = EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"追跡",
		"category": &"tracking",
		"inverse": &"復讐",
		"structure": EQRelationGraph.Structure.TREE,
	})
	rg.declare_relation_type({
		"name": &"復讐",
		"category": &"revenge",
		"inverse": &"追跡",
		"structure": EQRelationGraph.Structure.TREE,
	})
	rg.declare_relation_type({
		"name": &"解析",
		"category": &"analysis",
		"structure": EQRelationGraph.Structure.GRAPH,
	})

	var s1 = rg.bind(&"追跡", &"月", &"星")
	var s2 = rg.bind(&"追跡", &"月", &"星2")
	rg.bind(&"解析", &"星", &"星2")
	rg.bind(&"解析", &"星2", &"星")
	t.ok(s1 != &"" and s2 != &"", "summon tree: one moon tracks two stars")
	t.ok(rg.invert(s1), "復讐は追跡の inverse")
	var inv = rg.relation(s1)
	t.eq(inv.get("type", &""), &"復讐", "inverted relation becomes revenge")


static func _json_rows(trace_jsonl: String) -> Array:
	var rows = []
	for line in trace_jsonl.split("\n"):
		if line == "":
			continue
		var v = JSON.parse_string(line)
		if v is Dictionary:
			rows.append(v)
	return rows


static func _has_trace(rows: Array, kind: String, relation_id: String) -> bool:
	for row in rows:
		if String(row.get("kind", "")) == kind and String(row.get("relation", "")) == relation_id:
			return true
	return false


static func _count_kind(rows: Array, kind: String) -> int:
	var count = 0
	for row in rows:
		if String(row.get("kind", "")) == kind:
			count += 1
	return count


static func _count_with_context(rows: Array, kind: String, key: String, value: StringName) -> int:
	var count = 0
	for row in rows:
		if String(row.get("kind", "")) == kind and String(row.get(key, "")) == String(value):
			count += 1
	return count


static func _relation_id_strings(relations: Array) -> Array[String]:
	var out: Array[String] = []
	for relation_payload in relations:
		out.append(String((relation_payload as Dictionary).get("relation_id", "")))
	return out


static func _trace_relation_ids(rows: Array, kind: String) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		if String(row.get("kind", "")) == kind:
			out.append(String(row.get("relation", "")))
	return out


static func _trace_field(rows: Array, kind: String, key: String, value: String, field: String) -> StringName:
	for row in rows:
		if String(row.get("kind", "")) == kind and String(row.get(key, "")) == String(value):
			return StringName(row.get(field, ""))
	return &""
