extends RefCounted
## EQM-122: relation graph backend contract tests.

const EQRelationGraph = preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")
const EQTrace = preload("res://addons/event_queue_manager/runtime/eq_trace.gd")
const EQConditionSpec = preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")


static func run(t) -> void:
	_test_declare_type_redeclaration_and_invalid(t)
	_test_bind_dissolve_invert_and_trace(t)
	_test_serial_rebound_chain(t)
	_test_invalidate_actor(t)
	_test_maintenance(t)
	_test_roundtrip(t)
	_test_lunar_stellar_acceptance_example(t)
	_test_reservation_runtime_wiring(t)


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
	t.eq(_count_kind(rows, "relation_dissolved"), 2, "invalidate_actor emits dissolve trace")
	t.eq(_count_with_context(rows, "relation_dissolved", "cause", &"actor_removed"), 2, "invalidate_actor uses actor_removed cause")
	t.eq(_count_kind(rows, "relation_rebound"), 1, "invalidate_actor may apply serial rebound")
	t.ok(rg.relations_of(&"B").is_empty(), "actor B has no relations afterwards")


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


static func _trace_field(rows: Array, kind: String, key: String, value: String, field: String) -> StringName:
	for row in rows:
		if String(row.get("kind", "")) == kind and String(row.get(key, "")) == String(value):
			return StringName(row.get(field, ""))
	return &""
