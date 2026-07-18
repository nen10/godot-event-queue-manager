extends RefCounted
## EQM-139 independent performance lane: production actor adjacency compared
## with test-only copies of the removed full-table paths. Elapsed ratios are
## advisory; exact result/order/state/trace and inspected-id counts are hard gates.

const EQRelationGraph := preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")

const TOTAL_RELATIONS := 2048
const FOCUS := &"focus"
const LINK := &"link"
const OTHER := &"other"
const LINK_INDEXES := [2, 17, 128, 333, 777, 1024, 1536, 2048]
const OTHER_INDEX := 511
const INCIDENT_RELATIONS := 9
const QUERY_ITERATIONS := 80
const SELECTION_ITERATIONS := 150
const EXPAND_ITERATIONS := 6
const BENCHMARK_SAMPLES := 6


class CountingRelationGraph extends EQRelationGraph:
	var count_work := false
	var incident_calls := 0
	var incident_ids := 0
	var global_id_calls := 0

	func reset_work() -> void:
		incident_calls = 0
		incident_ids = 0
		global_id_calls = 0

	func _incident_relation_ids(actor: StringName) -> Array:
		var ids: Array = super._incident_relation_ids(actor)
		if count_work:
			incident_calls += 1
			incident_ids += ids.size()
		return ids

	func relation_ids() -> Array:
		if count_work:
			global_id_calls += 1
		return super.relation_ids()


static func run(t) -> void:
	var graph := _build_graph()
	_test_relations_of(t, graph)
	_test_expand(t, graph)
	_test_invalidation(t)


static func _test_relations_of(t, graph: CountingRelationGraph) -> void:
	var legacy: Array = _legacy_relations_of(graph, FOCUS)
	var current: Array = graph.relations_of(FOCUS)
	t.eq(current, legacy, "adjacency relations_of is exact payload/order equivalent to legacy full scan")
	t.eq(current.size(), INCIDENT_RELATIONS, "relations_of returns the declared sparse incident degree")

	graph.reset_work()
	graph.count_work = true
	graph.relations_of(FOCUS)
	graph.count_work = false
	t.eq(graph.incident_calls, 1, "production relations_of performs one actor adjacency lookup")
	t.eq(graph.incident_ids, INCIDENT_RELATIONS, "production relations_of inspects only incident ids")
	t.eq(graph.global_id_calls, 0, "production relations_of does not enumerate global relation ids")
	t.ok(
		TOTAL_RELATIONS > graph.incident_ids * 100,
		"sparse query removes more than 100x deterministic id inspections",
	)

	var timing := _measure_pair(
		func(): return _legacy_relations_of(graph, FOCUS),
		func(): return graph.relations_of(FOCUS),
		QUERY_ITERATIONS,
	)
	_print_timing("relations_of", QUERY_ITERATIONS, timing)


static func _test_expand(t, graph: CountingRelationGraph) -> void:
	var legacy_work: Dictionary = _legacy_expand_work(graph, FOCUS, LINK, 1, 2)
	graph.reset_work()
	graph.count_work = true
	var current: Array = graph.expand(FOCUS, LINK, 1, 2)
	graph.count_work = false

	t.eq(current, legacy_work["result"], "adjacency expand is exact BFS/order equivalent to legacy full scan")
	t.eq(current.size(), 1 + LINK_INDEXES.size(), "bounded expansion reaches every declared focus leaf once")
	t.eq(
		graph.incident_calls,
		int(legacy_work["frontier_frames"]),
		"production and legacy expansion process the same frontier frames",
	)
	t.eq(graph.global_id_calls, 0, "production expand does not enumerate global relation ids")
	t.ok(
		int(legacy_work["inspected_ids"]) > graph.incident_ids * 100,
		"sparse expansion removes more than 100x deterministic id inspections",
	)

	var timing := _measure_pair(
		func(): return _legacy_expand_timed(graph, FOCUS, LINK, 1, 2),
		func(): return graph.expand(FOCUS, LINK, 1, 2),
		EXPAND_ITERATIONS,
	)
	_print_timing("expand", EXPAND_ITERATIONS, timing)
	print(
		("[performance] relation-adjacency-work path=expand total_relations=%d "
		+ "frontier_frames=%d legacy_inspected=%d adjacency_inspected=%d")
		% [
			TOTAL_RELATIONS,
			legacy_work["frontier_frames"],
			legacy_work["inspected_ids"],
			graph.incident_ids,
		]
	)


static func _test_invalidation(t) -> void:
	var legacy_trace := EQTrace.new()
	var legacy_graph := _build_graph(legacy_trace)
	var current_trace := EQTrace.new()
	var current_graph := _build_graph(current_trace)
	var legacy_count := _legacy_invalidate_actor(legacy_graph, FOCUS)

	current_graph.reset_work()
	current_graph.count_work = true
	var current_count := current_graph.invalidate_actor(FOCUS)
	current_graph.count_work = false
	t.eq(current_count, legacy_count, "adjacency invalidation dissolves the same original incident count")
	t.eq(current_count, INCIDENT_RELATIONS, "invalidation consumes the declared sparse incident set")
	t.eq(current_graph.to_dict(), legacy_graph.to_dict(), "adjacency invalidation leaves exact legacy graph state")
	t.eq(current_trace.to_jsonl(), legacy_trace.to_jsonl(), "adjacency invalidation emits exact legacy trace order")
	t.eq(current_graph.incident_calls, 1, "production invalidation snapshots adjacency once")
	t.eq(current_graph.incident_ids, INCIDENT_RELATIONS, "production invalidation inspects only original incident ids")
	t.eq(current_graph.global_id_calls, 0, "production invalidation does not enumerate global relation ids")

	var selection_graph := _build_graph()
	var legacy_selection: Array = _legacy_impacted(selection_graph, FOCUS)
	var current_selection: Array = selection_graph._incident_relation_ids(FOCUS)
	t.eq(current_selection, legacy_selection, "adjacency invalidation selection is exact legacy id order")
	var timing := _measure_pair(
		func(): return _legacy_impacted(selection_graph, FOCUS),
		func(): return selection_graph._incident_relation_ids(FOCUS),
		SELECTION_ITERATIONS,
	)
	_print_timing("invalidate-selection", SELECTION_ITERATIONS, timing)


static func _build_graph(trace = null) -> CountingRelationGraph:
	var graph := CountingRelationGraph.new(trace)
	graph.restore(_snapshot())
	return graph


static func _snapshot() -> Dictionary:
	var relations: Array = []
	for relation_index in range(1, TOTAL_RELATIONS + 1):
		var type := LINK
		var from_actor := StringName("unrelated.%04d.left" % relation_index)
		var to_actor := StringName("unrelated.%04d.right" % relation_index)
		if LINK_INDEXES.has(relation_index):
			from_actor = FOCUS
			to_actor = StringName("focus.leaf.%04d" % relation_index)
		elif relation_index == OTHER_INDEX:
			type = OTHER
			from_actor = FOCUS
			to_actor = &"focus.other"
		relations.append({
			"relation_id": StringName("eqm.rel.%d" % relation_index),
			"type": type,
			"from": from_actor,
			"to": to_actor,
		})
	return {
		"relation_types": [
			{"name": LINK, "structure": EQRelationGraph.Structure.GRAPH},
			{"name": OTHER, "structure": EQRelationGraph.Structure.GRAPH},
		],
		"relations": relations,
		"relation_seq": TOTAL_RELATIONS,
	}


## Exact test-only copy of the removed production relations_of() code shape.
static func _legacy_relations_of(graph, actor: StringName) -> Array:
	var ids: Array = graph.relation_ids()
	var out: Array = []
	for relation_id in ids:
		var relation_payload: Dictionary = graph._relations[relation_id]
		if relation_payload["from_actor"] == actor or relation_payload["to_actor"] == actor:
			out.append(relation_payload.duplicate(true))
	return out


## Exact test-only copy of the removed production invalidation selection.
static func _legacy_impacted(graph, actor: StringName) -> Array:
	var impacted: Array = []
	for relation_id in graph._relations:
		var relation_payload: Dictionary = graph._relations[relation_id]
		if relation_payload["from_actor"] == actor or relation_payload["to_actor"] == actor:
			impacted.append(relation_id)
	impacted.sort_custom(func(a, b): return String(a) < String(b))
	return impacted


static func _legacy_invalidate_actor(graph, actor: StringName) -> int:
	var count := 0
	for relation_id in _legacy_impacted(graph, actor):
		if graph.dissolve(relation_id, &"actor_removed"):
			count += 1
	return count


## Instrumented legacy oracle for deterministic work counts. Never timed.
static func _legacy_expand_work(
	graph, origin: StringName, relation_type: StringName, hop_cost: int, budget: int
) -> Dictionary:
	var out: Array[StringName] = [origin]
	if relation_type == &"" or hop_cost <= 0 or budget <= 0:
		return {"result": out, "inspected_ids": 0, "frontier_frames": 0}
	var relation_ids: Array = graph.relation_ids()
	var frontier: Array = [{"actor": origin, "cost": 0}]
	var frontier_index := 0
	var inspected_ids := 0
	while frontier_index < frontier.size():
		var frame: Dictionary = frontier[frontier_index]
		frontier_index += 1
		var current := StringName(frame.get("actor", ""))
		var spent := int(frame.get("cost", 0))
		for relation_id in relation_ids:
			inspected_ids += 1
			var relation_payload: Dictionary = graph.relation(StringName(relation_id))
			if relation_payload.is_empty():
				continue
			if StringName(relation_payload.get("type", "")) != relation_type:
				continue
			var next: StringName = &""
			if relation_payload.get("from_actor", &"") == current:
				next = StringName(relation_payload.get("to_actor", ""))
			elif relation_payload.get("to_actor", &"") == current:
				next = StringName(relation_payload.get("from_actor", ""))
			else:
				continue
			var next_cost := spent + hop_cost
			if next_cost > budget:
				continue
			var should_append := true
			for actor in out:
				if String(actor) == String(next):
					should_append = false
					break
			if should_append:
				out.append(next)
			frontier.append({"actor": next, "cost": next_cost})
	return {
		"result": out,
		"inspected_ids": inspected_ids,
		"frontier_frames": frontier_index,
	}


## Exact test-only copy of the removed production expand() code shape. It stays
## free of work counters/result wrappers so the advisory elapsed A/B is fair.
static func _legacy_expand_timed(
	graph, origin: StringName, relation_type: StringName, hop_cost: int, budget: int
) -> Array:
	var out: Array[StringName] = [origin]
	if relation_type == &"" or hop_cost <= 0 or budget <= 0:
		return out
	var relation_ids: Array = graph.relation_ids()
	var frontier: Array = [{"actor": origin, "cost": 0}]
	var frontier_index := 0
	while frontier_index < frontier.size():
		var frame: Dictionary = frontier[frontier_index]
		frontier_index += 1
		var current := StringName(frame.get("actor", ""))
		var spent := int(frame.get("cost", 0))
		for relation_id in relation_ids:
			var relation_payload: Dictionary = graph.relation(StringName(relation_id))
			if relation_payload.is_empty():
				continue
			if StringName(relation_payload.get("type", "")) != relation_type:
				continue
			var next: StringName = &""
			if relation_payload.get("from_actor", &"") == current:
				next = StringName(relation_payload.get("to_actor", ""))
			elif relation_payload.get("to_actor", &"") == current:
				next = StringName(relation_payload.get("from_actor", ""))
			else:
				continue
			var next_cost := spent + hop_cost
			if next_cost > budget:
				continue
			var should_append := true
			for actor in out:
				if String(actor) == String(next):
					should_append = false
					break
			if should_append:
				out.append(next)
			frontier.append({"actor": next, "cost": next_cost})
	return out


static func _measure_pair(legacy: Callable, current: Callable, iterations: int) -> Dictionary:
	for _warmup in range(5):
		legacy.call()
		current.call()
	var legacy_samples: Array[int] = []
	var current_samples: Array[int] = []
	var checksum := 0
	for sample in range(BENCHMARK_SAMPLES):
		if sample % 2 == 0:
			checksum += _measure_batch(legacy, iterations, legacy_samples)
			checksum += _measure_batch(current, iterations, current_samples)
		else:
			checksum += _measure_batch(current, iterations, current_samples)
			checksum += _measure_batch(legacy, iterations, legacy_samples)
	if checksum <= 0:
		return {"legacy_usec": 0, "current_usec": 0, "speedup": 0.0}
	legacy_samples.sort()
	current_samples.sort()
	var upper_median := int(BENCHMARK_SAMPLES / 2)
	var lower_median := upper_median - 1
	var legacy_usec := int((legacy_samples[lower_median] + legacy_samples[upper_median]) / 2)
	var current_usec := int((current_samples[lower_median] + current_samples[upper_median]) / 2)
	return {
		"legacy_usec": legacy_usec,
		"current_usec": current_usec,
		"speedup": float(legacy_usec) / float(maxi(current_usec, 1)),
		"legacy_samples": legacy_samples,
		"current_samples": current_samples,
	}


static func _measure_batch(operation: Callable, iterations: int, samples: Array[int]) -> int:
	var checksum := 0
	var started := Time.get_ticks_usec()
	for _iteration in range(iterations):
		var result: Array = operation.call()
		checksum += result.size()
	samples.append(Time.get_ticks_usec() - started)
	return checksum


static func _print_timing(path: String, iterations: int, timing: Dictionary) -> void:
	print(
		("[performance] relation-adjacency path=%s total_relations=%d incident=%d "
		+ "iterations=%d legacy_usec=%d adjacency_usec=%d speedup=%.2fx "
		+ "legacy_samples=%s adjacency_samples=%s")
		% [
			path,
			TOTAL_RELATIONS,
			INCIDENT_RELATIONS,
			iterations,
			timing["legacy_usec"],
			timing["current_usec"],
			timing["speedup"],
			str(timing["legacy_samples"]),
			str(timing["current_samples"]),
		]
	)
