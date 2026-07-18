extends RefCounted
## EQM-112 — progression performance budgets (SEM §12.1, Q43): the polling +
## sweep machinery must stay within the declared per-advance budget at the v1.x
## target scale (watched lines <= 300, actors <= 200, +0.5ms per advance()).
## Like EQM-102, this is a coarse independent-performance guard (declared budget
## with CI headroom), not a standard-regression test or microbenchmark.

const EQEventLines := preload("res://addons/event_queue_manager/runtime/eq_event_lines.gd")
const EQActorRegistry := preload("res://addons/event_queue_manager/runtime/eq_actor_registry.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")

const WATCHED_LINES := 300
const ACTORS := 200
const POLLS := 200
## Declared budget: 0.5 ms per poll step at target scale (SEM §12.1) -> 100 ms
## for 200 polls; guard at 4x for CI variance (same stance as EQM-102).
const POLL_BUDGET_MS := 400
const SWEEPS := 50
## Sweep budget shares the same 0.5 ms/advance envelope -> 25 ms for 50 sweeps; 4x headroom.
const SWEEP_BUDGET_MS := 100
const SPARSE_TOTAL_LINES := 4096
const SPARSE_WATCHED_LINES := 32
const UNKNOWN_WATCHED_LINES := 4
const SELECTION_ITERATIONS := 80
const RATE_MODIFIER_DEPTH := 32
const RATE_LOOKUP_ITERATIONS := 5000
const BENCHMARK_SAMPLES := 6


static func run(t) -> void:
	_test_sparse_poll_selection(t)
	_test_effective_rate_cache(t)
	_test_poll_budget(t)
	_test_sweep_budget(t)


static func _test_sparse_poll_selection(t) -> void:
	var lines := EQEventLines.new()
	for line_index in range(SPARSE_TOTAL_LINES):
		lines.issue(StringName("sparse.line.%04d" % line_index), 0, 1)
	var watched := {}
	for watched_index in range(SPARSE_WATCHED_LINES):
		var line_index := (watched_index * 127) % SPARSE_TOTAL_LINES
		var line_id := StringName("sparse.line.%04d" % line_index)
		var watched_key = String(line_id) if watched_index % 2 == 0 else line_id
		watched[watched_key] = watched_index % 3 == 0
	for unknown_index in range(UNKNOWN_WATCHED_LINES):
		watched[StringName("sparse.unknown.%02d" % unknown_index)] = true

	var legacy: Array = _legacy_live_watched_ids(lines, watched)
	var current: Array = lines._live_watched_ids(watched)
	t.eq(current, legacy, "watched-key selector is exact legacy content-order equivalent")
	t.eq(current.size(), SPARSE_WATCHED_LINES, "selector returns every live watched line exactly once")
	t.eq(lines.line_ids().size(), SPARSE_TOTAL_LINES + 1, "sparse fixture includes all declared lines plus primary")
	t.eq(
		watched.size(),
		SPARSE_WATCHED_LINES + UNKNOWN_WATCHED_LINES,
		"selection workload includes declared unknown watched keys",
	)
	t.ok(
		SPARSE_TOTAL_LINES + 1 > watched.size() * 100,
		"watched-key selection removes more than 100x deterministic key inspections",
	)

	var timing := _measure_pair(
		func(): return _legacy_live_watched_ids(lines, watched),
		func(): return lines._live_watched_ids(watched),
		SELECTION_ITERATIONS,
	)
	_print_timing(
		"poll-selection",
		SELECTION_ITERATIONS,
		"source_keys=%d->%d,live=%d" % [SPARSE_TOTAL_LINES + 1, watched.size(), current.size()],
		timing,
	)


static func _test_effective_rate_cache(t) -> void:
	var lines := EQEventLines.new()
	var line_id := &"rate.cache.benchmark"
	lines.issue(line_id, 0, 7)
	for modifier_index in range(RATE_MODIFIER_DEPTH):
		lines.add_rate_modifier(line_id, "add", modifier_index + 1)
	var legacy := _legacy_effective_rate_of(lines, line_id)
	var current := lines.effective_rate_of(line_id)
	t.eq(current, legacy, "cached effective rate is exact legacy modifier-scan equivalent")
	t.eq(
		(lines._lines[line_id]["modifiers"] as Array).size(),
		RATE_MODIFIER_DEPTH,
		"rate lookup fixture carries the declared modifier depth",
	)
	t.eq(lines._effective_rates[line_id], legacy, "production cache stores the derived canonical result")

	var timing := _measure_pair(
		func(): return _legacy_effective_rate_of(lines, line_id),
		func(): return lines.effective_rate_of(line_id),
		RATE_LOOKUP_ITERATIONS,
	)
	_print_timing(
		"effective-rate",
		RATE_LOOKUP_ITERATIONS,
		"modifier_inspections=%d->0,cache_reads=0->1" % RATE_MODIFIER_DEPTH,
		timing,
	)


static func _test_poll_budget(t) -> void:
	var el := EQEventLines.new(EQTrace.new())  # trace attached: the honest cost
	var watched := {}
	for i in WATCHED_LINES:
		var id := StringName("line.%03d" % i)
		el.issue(id, 0, 1 + (i % 3))
		watched[id] = true
	var start := Time.get_ticks_usec()
	for _p in POLLS:
		el.poll_tick(watched)
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	t.ok(ms <= POLL_BUDGET_MS, "%d polls of %d watched lines within %dms budget (took %.1fms)" % [POLLS, WATCHED_LINES, POLL_BUDGET_MS, ms])
	t.eq(el.value_of(&"line.000"), POLLS, "budget run advanced correctly (rate 1 x %d polls)" % POLLS)


static func _test_sweep_budget(t) -> void:
	var el := EQEventLines.new(EQTrace.new())
	var reg := EQActorRegistry.new()
	for i in ACTORS:
		var id := StringName("actor.%03d" % i)
		reg.register(id)
		reg.get_state(id).data["speed"] = 1 + (i % 5)
		el.issue(StringName("ct.%s" % id), 0, 0)
	el.register_sweep_rule(&"ct_charge", func(actor_id: StringName, data: Dictionary, lines) -> void:
		lines.advance(StringName("ct.%s" % actor_id), int(data["speed"])))
	var start := Time.get_ticks_usec()
	for _s in SWEEPS:
		el.run_sweep_rules(reg)
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	t.ok(ms <= SWEEP_BUDGET_MS, "%d sweeps over %d actors within %dms budget (took %.1fms)" % [SWEEPS, ACTORS, SWEEP_BUDGET_MS, ms])
	t.eq(el.value_of(&"ct.actor.000"), SWEEPS, "sweep advanced per-entity params correctly")


## Exact test-only copy of the removed production line_ids()+membership selector.
static func _legacy_live_watched_ids(lines, watched: Dictionary) -> Array:
	var out: Array = []
	for line_id in lines.line_ids():
		if watched.has(line_id):
			out.append(line_id)
	return out


## Exact test-only copy of the removed production effective_rate_of() code shape.
static func _legacy_effective_rate_of(lines, line_id: StringName) -> int:
	if not lines._lines.has(line_id):
		return 0
	var line: Dictionary = lines._lines[line_id]
	var override_value: int = int(0)
	var has_override: bool = false
	var add_value: int = 0
	var modifiers: Array = line.get("modifiers", [])
	for i in range(modifiers.size()):
		var m: Dictionary = modifiers[i]
		var kind := String(m["kind"])
		if kind == "override":
			override_value = int(m["value"])
			has_override = true
		elif kind == "add":
			add_value += int(m["value"])
	var base_rate := int(line["rate"])
	return override_value if has_override else base_rate + add_value


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
		var result = operation.call()
		checksum += result.size() if result is Array else int(result)
	samples.append(Time.get_ticks_usec() - started)
	return checksum


static func _print_timing(
	path: String,
	iterations: int,
	work: String,
	timing: Dictionary,
) -> void:
	print(
		("[performance] event-line-sparse path=%s work=%s "
		+ "iterations=%d legacy_usec=%d current_usec=%d speedup=%.2fx "
		+ "legacy_samples=%s current_samples=%s")
		% [
			path,
			work,
			iterations,
			timing["legacy_usec"],
			timing["current_usec"],
			timing["speedup"],
			str(timing["legacy_samples"]),
			str(timing["current_samples"]),
		]
	)
