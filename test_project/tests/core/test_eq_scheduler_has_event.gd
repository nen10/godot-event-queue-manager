extends RefCounted
## EQM-144: EQScheduler.has_event() reports scheduler liveness in O(1), hiding
## stale backend artifacts from cancelled/rescheduled entries.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQSortedArrayBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd")


class CountingBackend extends EQSortedArrayBackend:
	var ordered_calls := 0

	func ordered() -> Array:
		ordered_calls += 1
		return super.ordered()


static func run(t) -> void:
	_test_has_event_lifecycle(t)
	_test_has_event_does_not_scan_backend(t)
	_test_has_event_after_restore(t)


static func _test_has_event_lifecycle(t) -> void:
	var s := EQScheduler.new()
	var id := s.push(5)
	t.ok(s.has_event(id), "pushed event is live")
	t.ok(not s.has_event(9999), "unknown event is not live")
	t.ok(s.reschedule(id, 8), "reschedule live event")
	t.ok(s.has_event(id), "rescheduled event id remains live")
	t.eq(s.pop().event_id, id, "pop the rescheduled event")
	t.ok(not s.has_event(id), "popped event is no longer live")


static func _test_has_event_does_not_scan_backend(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var id := s.push(1)
	b.ordered_calls = 0
	t.ok(s.has_event(id), "has_event returns true for live event")
	t.eq(b.ordered_calls, 0, "has_event does not call backend.ordered()")
	t.ok(s.cancel(id), "cancel event")
	t.ok(not s.has_event(id), "cancelled event is not live even though backend still holds a stale artifact")
	t.eq(b.ordered_calls, 0, "has_event cancel check still does not scan backend")


static func _test_has_event_after_restore(t) -> void:
	var original := EQScheduler.new()
	var live := original.push(3)
	var cancelled := original.push(4)
	t.ok(original.cancel(cancelled), "cancel one event before snapshot")
	var restored := EQScheduler.new()
	t.eq(restored.restore(original.snapshot()), 0, "restore succeeds")
	t.ok(restored.has_event(live), "restored live event is reported live")
	t.ok(not restored.has_event(cancelled), "cancelled non-snapshot event is not reported live after restore")
