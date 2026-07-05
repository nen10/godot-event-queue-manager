extends RefCounted
## EQM-125/126: fairness relation expansion + explicit intervention standard form.

const EQReservationRuntime = preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQRelationGraph = preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")
const EQReservation = preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition = preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition = preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQWindow = preload("res://addons/event_queue_manager/runtime/eq_window.gd")

const GOLDEN_CASE = "fairness_relation_chain"
const GOLDEN_PATH = "res://tests/golden/fairness_relation_chain.trace.jsonl"


static func run(t) -> void:
	_test_fairness_relation_chain(t)
	_test_intervention_standard_form(t)
	_golden(t)


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


static func _json_rows(trace_jsonl: String) -> Array:
	var rows = []
	for line in trace_jsonl.split("\n"):
		if line == "":
			continue
		var v = JSON.parse_string(line)
		if v is Dictionary:
			rows.append(v)
	return rows


static func _index_of_matching(rows: Array, predicate: Callable) -> int:
	for i in range(rows.size()):
		var row = rows[i]
		if predicate.call(row):
			return i
	return -1


static func _test_fairness_relation_chain(t) -> void:
	var rr := _rr([&"hero", &"ally"])

	var rg := EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"公平",
		"structure": EQRelationGraph.Structure.GRAPH,
	})
	rg.bind(&"公平", &"hero", &"ally")
	rr.relations = rg

	rr.declare_expansion_rule({
		"relation_type": &"公平",
		"effect_tag": &"裁定",
		"hop_cost": 1,
		"budget": 1,
	})

	var reaction_def := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction_def.duration = 1
	var attack_result := {"reaction": 0}
	rr.runtime.register_effect(&"裁定", func(view: Dictionary) -> Array:
		var targets: Array = view.get("targets", [])
		for target in targets:
			if String(target) == String(view.get("source", &"")):
				continue
			var rc := EQCondition.new()
			rc.match_source = StringName(view.get("source", &""))
			rc.require_tags = [&"裁定"]
			rr.submit(EQReservation.new(target, reaction_def), rc)
			attack_result["reaction"] += 1
		return []
	)

	var attack_def := _def(EQActionDefinition.Kind.IMMEDIATE)
	attack_def.effect_name = &"裁定"
	attack_def.tags = [&"裁定"]
	var atk := EQReservation.new(&"hero", attack_def)
	atk.target_id = &"ally"
	rr.submit(atk)

	rr.resolve_next()
	rr.resolve_next()
	var rows := _json_rows(rr.runtime.trace_jsonl())
	t.eq(attack_result["reaction"], 1, "fairness expansion produces one reflected reaction to ally")
	t.ok(_index_of_matching(rows, func(r): return String(r.get("kind", "")) == "targets_expanded") >= 0, "targets_expanded trace is emitted")
	var reaction_fired := _index_of_matching(rows, func(r): return String(r.get("kind", "")) == "reaction_fired" and String(r.get("actor", "")) == "ally")
	var reaction_event_id := -1
	for row in rows:
		if String(row.get("kind", "")) == "reaction_fired" and String(row.get("actor", "")) == "ally":
			reaction_event_id = int(row.get("event_id", -1))
			break
	var reaction_resolved := _index_of_matching(rows, func(r):
		return String(r.get("kind", "")) == "resolved" and int(r.get("event_id", -1)) == reaction_event_id
	)
	t.ok(reaction_fired >= 0, "Y-side reflection appears in reaction_fired")
	t.ok(reaction_event_id > 0, "reaction_fired includes a stable event_id")
	t.ok(reaction_resolved >= 0, "reflected reaction resolves")
	t.ok(reaction_fired < reaction_resolved, "reflection resolves after the sweep that fires it")


static func _test_intervention_standard_form(t) -> void:
	var rr := _rr([&"mover", &"interceptor"])
	var w: EQWindow = rr.open_window(&"mover", &"move", EQWindow.DEADLINE_UNLIMITED, 0, &"", 1)
	t.ok(w != null, "mover opens meta-level 1 window")
	if w == null:
		return

	rr.runtime.register_effect(&"hold", func(_v: Dictionary) -> Array:
		return []
	)
	var hold := _def(EQActionDefinition.Kind.PREPARED, 5)
	hold.effect_name = &"hold"
	var hold_res := EQReservation.new(&"mover", hold)
	hold_res.target_id = &"mover"
	var pending_id := rr.submit(hold_res)
	t.ok(pending_id > 0, "mover submits pending scheduled in pending window")

	var intervene_ok := {"value": false}
	var interceptor_id := -1
	var interceptor_ctx := {"event_id": -1}
	rr.runtime.register_effect(&"intercept", func(view: Dictionary) -> Array:
		intervene_ok["value"] = rr.intervene_close(w.window_id, {
			"meta_level": int(view.get("meta_level", 0)),
			"event_id": int(interceptor_ctx["event_id"]),
		})
		return []
	)
	var inter := _def(EQActionDefinition.Kind.IMMEDIATE)
	inter.effect_name = &"intercept"
	inter.meta_level = 1
	var interceptor := EQReservation.new(&"interceptor", inter)
	interceptor.target_id = &"mover"
	interceptor_id = rr.submit(interceptor)
	interceptor_ctx["event_id"] = interceptor_id
	t.ok(interceptor_id > 0, "interceptor reservation is queued")

	rr.resolve_next()
	var rows := _json_rows(rr.runtime.trace_jsonl())
	var resolved_idx := _index_of_matching(rows, func(r):
		return String(r.get("kind", "")) == "resolved" and int(r.get("event_id", -1)) == interceptor_id
	)
	var window_closed_idx := _index_of_matching(rows, func(r):
		return String(r.get("kind", "")) == "window_closed" and String(r.get("cause", "")) == "intervention"
	)
	var matched_trace := false
	for row in rows:
		if String(row.get("kind", "")) == "window_closed" and String(row.get("cause", "")) == "intervention":
			matched_trace = matched_trace or (int(row.get("window_id", -1)) == w.window_id and int(row.get("intervener_event_id", -1)) == interceptor_id)

	t.ok(intervene_ok["value"], "intervention succeeds from inside interceptor effect")
	t.ok(resolved_idx >= 0, "interceptor event resolved")
	t.ok(window_closed_idx >= 0, "intervention window_closed trace is emitted")
	t.ok(window_closed_idx > resolved_idx, "window_closed cause intervention appears after interceptor resolved")
	t.ok(matched_trace, "intervention trace keeps window and interceptor event context")
	t.eq(rr.window_depth(), 0, "pending windows are all closed")


static func _golden(t) -> void:
	var jsonl := _build_fairness_relation_chain_trace()
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
	t.eq(jsonl, want, "golden scenario trace matches fairness_relation_chain")


static func _build_fairness_relation_chain_trace() -> String:
	var rr := _rr([&"hero", &"ally"])
	var rg := EQRelationGraph.new()
	rg.declare_relation_type({
		"name": &"公平",
		"structure": EQRelationGraph.Structure.GRAPH,
	})
	rg.bind(&"公平", &"hero", &"ally")
	rr.relations = rg
	rr.declare_expansion_rule({
		"relation_type": &"公平",
		"effect_tag": &"裁定",
		"hop_cost": 1,
		"budget": 1,
	})

	var reaction_def := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction_def.duration = 1
	rr.runtime.register_effect(&"裁定", func(view: Dictionary) -> Array:
		var targets: Array = view.get("targets", [])
		for target in targets:
			if String(target) == String(view.get("source", &"")):
				continue
			var rc := EQCondition.new()
			rc.match_source = StringName(view.get("source", &""))
			rc.require_tags = [&"裁定"]
			rr.submit(EQReservation.new(target, reaction_def), rc)
		return []
	)

	var attack_def := _def(EQActionDefinition.Kind.IMMEDIATE)
	attack_def.effect_name = &"裁定"
	attack_def.tags = [&"裁定"]
	var atk := EQReservation.new(&"hero", attack_def)
	atk.target_id = &"ally"
	rr.submit(atk)

	rr.resolve_next()
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
	t.ok(true, "golden re-baselined for %s" % GOLDEN_CASE)


static func _dump_actual(jsonl: String) -> void:
	var out := OS.get_environment("EQ_RUN_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out + "/traces")
	var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
	if f != null:
		f.store_string(jsonl)
		f.close()
