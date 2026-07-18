extends RefCounted
## EQM-142 independent performance lane: live `peek_next()` avoids the old
## per-resolution full ordered() copy/sort when the backend minimum is live.
## Elapsed values are advisory; ordered-call and ordered-entry counts are the
## deterministic hard gates.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQBinaryHeapBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_binary_heap_backend.gd")

const DRAIN_N := 512


class CountingHeapBackend extends EQBinaryHeapBackend:
	var ordered_calls := 0
	var ordered_entries := 0
	var peek_min_calls := 0

	func ordered() -> Array:
		ordered_calls += 1
		ordered_entries += size()
		return super.ordered()

	func peek_min():
		peek_min_calls += 1
		return super.peek_min()


static func run(t) -> void:
	_test_live_peek_no_stale_work(t)


static func _test_live_peek_no_stale_work(t) -> void:
	var current_backend := CountingHeapBackend.new()
	var current := EQScheduler.new(current_backend)
	_fill(current, DRAIN_N)
	var started := Time.get_ticks_usec()
	var current_popped := _drain_current(current)
	var current_usec := Time.get_ticks_usec() - started

	var legacy_backend := CountingHeapBackend.new()
	var legacy := EQScheduler.new(legacy_backend)
	_fill(legacy, DRAIN_N)
	started = Time.get_ticks_usec()
	var legacy_popped := _drain_legacy(legacy)
	var legacy_usec := Time.get_ticks_usec() - started

	var expected_ordered_calls := DRAIN_N - 1
	var expected_ordered_entries := int(DRAIN_N * (DRAIN_N - 1) / 2)
	t.eq(current_popped, DRAIN_N, "current drain processes the declared scheduler workload")
	t.eq(legacy_popped, DRAIN_N, "legacy drain processes the declared scheduler workload")
	t.eq(current_backend.ordered_calls, 0, "current live-peek drain performs zero full ordered() copies")
	t.eq(current_backend.ordered_entries, 0, "current live-peek drain copies zero backend entries")
	t.eq(legacy_backend.ordered_calls, expected_ordered_calls, "legacy live-peek shape performs one ordered() copy after each pop except the last")
	t.eq(legacy_backend.ordered_entries, expected_ordered_entries, "legacy live-peek shape copies the triangular remaining-entry workload")
	t.ok(current_backend.peek_min_calls >= expected_ordered_calls, "current live-peek uses cheap backend minimum peeks")
	print("[perf][EQM-142] heap drain N=%d current=%d usec legacy=%d usec ordered_entries %d -> %d speedup=%.2fx" % [
		DRAIN_N,
		current_usec,
		legacy_usec,
		legacy_backend.ordered_entries,
		current_backend.ordered_entries,
		float(legacy_usec) / max(1, current_usec),
	])


static func _fill(s: EQScheduler, count: int) -> void:
	for i in count:
		var tick := (i * 2654435761) % count
		var priority := (i * 40503) % 7
		s.push(tick, priority, &"turn", StringName("a%d" % i))


static func _drain_current(s: EQScheduler) -> int:
	var n := 0
	while not s.is_empty():
		var e = s.pop()
		if e == null:
			break
		if not s.is_empty():
			s.peek_next()
		n += 1
	return n


static func _drain_legacy(s: EQScheduler) -> int:
	var n := 0
	while not s.is_empty():
		var e = s.pop()
		if e == null:
			break
		if not s.is_empty():
			_legacy_peek_next(s)
		n += 1
	return n


# Test-only copy of the removed pre-EQM-142 implementation.
static func _legacy_peek_next(s: EQScheduler):
	for e in s._backend.ordered():
		if s._is_live(e):
			return e
	return null
