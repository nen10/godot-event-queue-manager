extends RefCounted
## EQM-143 independent performance lane: reschedule() no longer finds the live
## entry by calling backend.ordered(). Elapsed is advisory; ordered-call and
## ordered-entry counts are deterministic hard gates.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQBinaryHeapBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_binary_heap_backend.gd")

const RESCHEDULE_N := 256


class CountingHeapBackend extends EQBinaryHeapBackend:
	var ordered_calls := 0
	var ordered_entries := 0

	func ordered() -> Array:
		ordered_calls += 1
		ordered_entries += size()
		return super.ordered()


static func run(t) -> void:
	_test_reschedule_lookup_work(t)


static func _test_reschedule_lookup_work(t) -> void:
	var current_backend := CountingHeapBackend.new()
	var current := EQScheduler.new(current_backend)
	var current_ids := _fill(current, RESCHEDULE_N)
	var started := Time.get_ticks_usec()
	var current_ok := _reschedule_current(current, current_ids)
	var current_usec := Time.get_ticks_usec() - started

	var legacy_backend := CountingHeapBackend.new()
	var legacy := EQScheduler.new(legacy_backend)
	var legacy_ids := _fill(legacy, RESCHEDULE_N)
	started = Time.get_ticks_usec()
	var legacy_ok := _reschedule_legacy_shape(legacy, legacy_ids)
	var legacy_usec := Time.get_ticks_usec() - started

	var expected_ordered_calls := RESCHEDULE_N
	# Before each legacy reschedule, the lazy backend contains the original N
	# entries plus one stale artifact for each prior reschedule.
	var expected_ordered_entries := int(RESCHEDULE_N * RESCHEDULE_N + (RESCHEDULE_N * (RESCHEDULE_N - 1)) / 2)
	t.eq(current_ok, RESCHEDULE_N, "current reschedules the declared workload")
	t.eq(legacy_ok, RESCHEDULE_N, "legacy-shape reschedules the declared workload")
	t.eq(current.size(), RESCHEDULE_N, "current live event count remains stable")
	t.eq(legacy.size(), RESCHEDULE_N, "legacy live event count remains stable")
	t.eq(current_backend.ordered_calls, 0, "current reschedule performs zero ordered() scans")
	t.eq(current_backend.ordered_entries, 0, "current reschedule copies zero backend entries for lookup")
	t.eq(legacy_backend.ordered_calls, expected_ordered_calls, "legacy lookup scans once per reschedule")
	t.eq(legacy_backend.ordered_entries, expected_ordered_entries, "legacy lookup copies the expected growing lazy-backend workload")
	print("[perf][EQM-143] heap reschedule N=%d current=%d usec legacy_shape=%d usec ordered_entries %d -> %d speedup=%.2fx" % [
		RESCHEDULE_N,
		current_usec,
		legacy_usec,
		legacy_backend.ordered_entries,
		current_backend.ordered_entries,
		float(legacy_usec) / max(1, current_usec),
	])


static func _fill(s: EQScheduler, count: int) -> Array:
	var ids := []
	for i in count:
		var tick := (i * 2654435761) % count
		var priority := (i * 40503) % 7
		ids.append(s.push(tick, priority, &"turn", StringName("a%d" % i), {"i": i}))
	return ids


static func _reschedule_current(s: EQScheduler, ids: Array) -> int:
	var ok := 0
	for i in ids.size():
		if s.reschedule(int(ids[i]), RESCHEDULE_N + i):
			ok += 1
	return ok


static func _reschedule_legacy_shape(s: EQScheduler, ids: Array) -> int:
	var ok := 0
	for i in ids.size():
		var cur = _legacy_find_live(s, int(ids[i]))
		if cur != null and s.reschedule(int(ids[i]), RESCHEDULE_N + i):
			ok += 1
	return ok


# Test-only copy of the removed old `_find_live` shape. The actual mutation then
# uses current reschedule so semantics stay identical; this isolates lookup work.
static func _legacy_find_live(s: EQScheduler, event_id: int):
	for e in s._backend.ordered():
		if e.event_id == event_id and s._is_live(e):
			return e
	return null
