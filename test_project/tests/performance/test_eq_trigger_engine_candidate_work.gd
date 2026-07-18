extends RefCounted
## EQM-136/138 performance lane: deterministic production-engine work gates plus
## an advisory legacy-sort vs stable-merge A/B. Never run by regression.

const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQTriggerIndex := preload("res://addons/event_queue_manager/runtime/eq_trigger_index.gd")

const TOTAL_ARMS := 1000
const TARGET_COUNT := 40
const RESOLVING_TARGET := &"target-7"
const SPARSE_WILDCARD_EVERY := 20
const HEAVY_WILDCARD_EVERY := 4
const BENCHMARK_ITERATIONS := 500
const BENCHMARK_SAMPLES := 6


class CountingCondition extends EQCondition:
	var match_calls: int = 0

	func matches(view: Dictionary) -> bool:
		match_calls += 1
		return super.matches(view)


static func run(t) -> void:
	_test_candidate_work_and_merge(t, &"sparse", SPARSE_WILDCARD_EVERY)
	_test_candidate_work_and_merge(t, &"wildcard-heavy", HEAVY_WILDCARD_EVERY)


static func _test_candidate_work_and_merge(
	t, scenario: StringName, wildcard_every: int
) -> void:
	var engine := EQTriggerEngine.new()
	var index := EQTriggerIndex.new()
	var conditions: Array[CountingCondition] = []
	var expected_candidates := 0

	for i in range(TOTAL_ARMS):
		var definition := EQActionDefinition.new()
		definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
		definition.duration = EQActionDefinition.DURATION_UNLIMITED
		var reservation := EQReservation.new(StringName("actor-%d" % i), definition)
		var condition := CountingCondition.new()
		if i % wildcard_every == 0:
			condition.match_target = &""
			expected_candidates += 1
		else:
			condition.match_target = StringName("target-%d" % (i % TARGET_COUNT))
			if condition.match_target == RESOLVING_TARGET:
				expected_candidates += 1
		# Keep every candidate armed after the sweep while still executing the
		# complete condition matcher.
		condition.require_tags = [&"never-present"]
		conditions.append(condition)
		engine.arm(reservation, condition, 0)
		index.add(reservation, condition)

	var view := {
		"kind": &"hit", "source": &"enemy", "target": RESOLVING_TARGET, "tags": [],
	}
	var started_usec := Time.get_ticks_usec()
	var fired := engine.on_event_resolved_occurrences(view, 1)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var actual_match_calls := 0
	for condition in conditions:
		actual_match_calls += condition.match_calls

	t.eq(fired.size(), 0, "non-matching performance workload keeps every arm open")
	t.eq(engine.armed_count(), TOTAL_ARMS, "performance sweep preserves all non-matching arms")
	t.eq(
		actual_match_calls,
		expected_candidates,
		"production engine evaluates only target-bucket plus wildcard candidates"
	)
	if scenario == &"sparse":
		t.ok(expected_candidates < TOTAL_ARMS / 4, "sparse candidate work stays below one quarter")
	else:
		t.ok(
			expected_candidates >= TOTAL_ARMS / 4 and expected_candidates < TOTAL_ARMS / 2,
			"wildcard-heavy fixture stays between one quarter and one half of armed slots"
		)

	var merged_sequences: Array = index.candidates(view).map(func(entry): return int(entry["seq"]))
	var legacy_sequences: Array = _legacy_candidates(index, view).map(
		func(entry): return int(entry["seq"])
	)
	t.eq(merged_sequences, legacy_sequences, "stable merge is exact sequence-order equivalent to legacy sort")
	var timing := _measure_candidate_assemblers(index, view)
	print(
		("[performance] trigger-candidate-merge scenario=%s total_arms=%d candidates=%d "
		+ "match_calls=%d sweep_usec=%d iterations=%d legacy_usec=%d merge_usec=%d speedup=%.2fx "
		+ "legacy_samples=%s merge_samples=%s")
		% [
			String(scenario), TOTAL_ARMS, expected_candidates, actual_match_calls,
			elapsed_usec, BENCHMARK_ITERATIONS, timing["legacy_usec"],
			timing["merge_usec"], timing["speedup"], str(timing["legacy_samples"]),
			str(timing["merge_samples"]),
		]
	)


## Exact test-only copy of the removed production candidates() code shape.
static func _legacy_candidates(index, view: Dictionary) -> Array:
	var target: StringName = view.get("target", &"")
	var out: Array = []
	if index._by_target.has(target):
		out.append_array(index._by_target[target])
	out.append_array(index._wildcard)
	out.sort_custom(func(a, b): return int(a["seq"]) < int(b["seq"]))
	return out


static func _measure_candidate_assemblers(index, view: Dictionary) -> Dictionary:
	for _warmup in range(20):
		_legacy_candidates(index, view)
		index.candidates(view)
	var legacy_samples: Array[int] = []
	var merge_samples: Array[int] = []
	var checksum := 0
	for sample in range(BENCHMARK_SAMPLES):
		if sample % 2 == 0:
			checksum += _measure_legacy_batch(index, view, legacy_samples)
			checksum += _measure_merge_batch(index, view, merge_samples)
		else:
			checksum += _measure_merge_batch(index, view, merge_samples)
			checksum += _measure_legacy_batch(index, view, legacy_samples)
	# Keeps both loops observably live without making elapsed a correctness gate.
	if checksum <= 0:
		return {"legacy_usec": 0, "merge_usec": 0, "speedup": 0.0}
	legacy_samples.sort()
	merge_samples.sort()
	var upper_median := int(BENCHMARK_SAMPLES / 2)
	var lower_median := upper_median - 1
	var legacy_usec := int(
		(legacy_samples[lower_median] + legacy_samples[upper_median]) / 2
	)
	var merge_usec := int(
		(merge_samples[lower_median] + merge_samples[upper_median]) / 2
	)
	return {
		"legacy_usec": legacy_usec,
		"merge_usec": merge_usec,
		"speedup": float(legacy_usec) / float(maxi(merge_usec, 1)),
		"legacy_samples": legacy_samples,
		"merge_samples": merge_samples,
	}


static func _measure_legacy_batch(index, view: Dictionary, samples: Array[int]) -> int:
	var checksum := 0
	var started := Time.get_ticks_usec()
	for _iteration in range(BENCHMARK_ITERATIONS):
		checksum += _legacy_candidates(index, view).size()
	samples.append(Time.get_ticks_usec() - started)
	return checksum


static func _measure_merge_batch(index, view: Dictionary, samples: Array[int]) -> int:
	var checksum := 0
	var started := Time.get_ticks_usec()
	for _iteration in range(BENCHMARK_ITERATIONS):
		checksum += index.candidates(view).size()
	samples.append(Time.get_ticks_usec() - started)
	return checksum
