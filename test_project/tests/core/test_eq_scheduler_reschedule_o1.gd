extends RefCounted
## EQM-143: reschedule() uses the scheduler's event_id -> live-entry
## accelerator instead of scanning/copying backend. Public semantics remain the
## existing lazy-invalidation contract.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQSortedArrayBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd")


class CountingBackend extends EQSortedArrayBackend:
	var ordered_calls := 0

	func ordered() -> Array:
		ordered_calls += 1
		return super.ordered()


static func run(t) -> void:
	_test_reschedule_does_not_scan_backend(t)
	_test_cancelled_event_not_rescheduled_from_live_map(t)
	_test_popped_event_not_rescheduled_from_live_map(t)
	_test_restore_rebuilds_live_map(t)
	_test_invalid_reschedule_does_not_replace_live_entry(t)


static func _test_reschedule_does_not_scan_backend(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var id := s.push(5, 7, &"turn", &"actor-a", {"hp": 3})
	b.ordered_calls = 0
	t.ok(s.reschedule(id, 2), "reschedule succeeds for a live event")
	t.eq(b.ordered_calls, 0, "reschedule does not call backend.ordered()")
	var e := s.peek_next()
	t.eq(e.event_id, id, "same event id remains live after reschedule")
	t.eq(e.kind, &"turn", "reschedule preserves kind from live-entry map")
	t.eq(e.actor_id, &"actor-a", "reschedule preserves actor from live-entry map")
	t.eq(e.payload["hp"], 3, "reschedule preserves payload from live-entry map")
	t.eq(e.due_tick, 2, "reschedule updates due tick")


static func _test_cancelled_event_not_rescheduled_from_live_map(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var id := s.push(4)
	t.ok(s.cancel(id), "cancel live event")
	b.ordered_calls = 0
	t.ok(not s.reschedule(id, 9), "cancelled event cannot be rescheduled")
	t.eq(b.ordered_calls, 0, "cancelled reschedule rejection does not scan backend")


static func _test_popped_event_not_rescheduled_from_live_map(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var id := s.push(1)
	t.eq(s.pop().event_id, id, "pop live event")
	b.ordered_calls = 0
	t.ok(not s.reschedule(id, 5), "popped event cannot be rescheduled")
	t.eq(b.ordered_calls, 0, "popped reschedule rejection does not scan backend")


static func _test_restore_rebuilds_live_map(t) -> void:
	var original := EQScheduler.new()
	var id := original.push(5, 1, &"turn", &"actor-a")
	var snap := original.snapshot()
	var b := CountingBackend.new()
	var restored := EQScheduler.new(b)
	t.eq(restored.restore(snap), 0, "restore succeeds")
	b.ordered_calls = 0
	t.ok(restored.reschedule(id, 2), "reschedule after restore uses rebuilt live map")
	t.eq(b.ordered_calls, 0, "restore-rebuilt live map avoids backend scan")
	t.eq(restored.peek_next().due_tick, 2, "restored scheduler has rescheduled tick")


static func _test_invalid_reschedule_does_not_replace_live_entry(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var id := s.push(6, 0, &"turn", &"actor-a")
	t.ok(not s.reschedule(id, -1), "invalid negative tick is rejected")
	var e := s.peek_next()
	t.eq(e.event_id, id, "event remains live after invalid reschedule")
	t.eq(e.due_tick, 6, "invalid reschedule does not mutate live entry")
