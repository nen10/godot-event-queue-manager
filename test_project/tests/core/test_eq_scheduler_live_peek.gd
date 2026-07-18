extends RefCounted
## EQM-142: EQScheduler.peek_next() answers from the backend minimum in O(1)
## when that minimum is live, and falls back to the ordered live scan only when
## the front is stale. Behavior (returned entry) is identical to the pre-EQM-142
## unconditional ordered() scan; the difference is inspected work, proven with a
## counting backend that records ordered() calls.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQSortedArrayBackend := preload("res://addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd")


## Sorted-array backend that counts how often the scheduler asks for a full
## ordered copy vs a cheap minimum peek.
class CountingBackend extends EQSortedArrayBackend:
	var ordered_calls := 0
	var peek_min_calls := 0

	func ordered() -> Array:
		ordered_calls += 1
		return super.ordered()

	func peek_min():
		peek_min_calls += 1
		return super.peek_min()


static func run(t) -> void:
	_test_empty_and_single(t)
	_test_live_min_is_o1(t)
	_test_cancel_front_fallback(t)
	_test_reschedule_front_fallback(t)
	_test_matches_legacy_scan(t)
	_test_drain_avoids_full_copies(t)


static func _test_empty_and_single(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	t.ok(s.peek_next() == null, "peek_next on empty -> null")
	var id := s.push(5, 0, &"a")
	b.ordered_calls = 0
	var e := s.peek_next()
	t.ok(e != null and e.event_id == id, "peek_next returns the only live entry")
	t.eq(b.ordered_calls, 0, "live-min peek does not copy the whole backend")


static func _test_live_min_is_o1(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	s.push(8, 0, &"a")
	var early := s.push(2, 0, &"b")
	s.push(8, 5, &"c")
	b.ordered_calls = 0
	b.peek_min_calls = 0
	var e := s.peek_next()
	t.ok(e != null and e.event_id == early, "peek_next returns EQOrdering minimum (live)")
	t.eq(b.ordered_calls, 0, "no full ordered() copy when the minimum is live")
	t.ok(b.peek_min_calls >= 1, "fast path consults peek_min()")


static func _test_cancel_front_fallback(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var front := s.push(1, 0, &"front")
	var next := s.push(4, 0, &"next")
	t.ok(s.cancel(front), "cancel the current minimum")
	b.ordered_calls = 0
	var e := s.peek_next()
	t.ok(e != null and e.event_id == next, "stale-front peek_next returns the next live entry")
	t.eq(b.ordered_calls, 1, "stale front falls back to a single ordered() scan")


static func _test_reschedule_front_fallback(t) -> void:
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var a := s.push(1, 0, &"a")   # minimum
	var kept := s.push(3, 0, &"b")
	# Reschedule a to a later tick: its old front entry becomes stale.
	t.ok(s.reschedule(a, 9), "reschedule the minimum to a later tick")
	var e := s.peek_next()
	# b is now the earliest live entry (tick 3 < 9).
	t.ok(e != null and e.event_id == kept, "reschedule-front peek_next returns the new earliest live entry")


static func _test_matches_legacy_scan(t) -> void:
	# The fast path must equal the old unconditional ordered() live scan across a
	# mixed sequence including cancels and reschedules.
	var s := EQScheduler.new()
	var a := s.push(8, 0, &"a")
	var _b := s.push(3, 0, &"b")
	var c := s.push(8, 5, &"c")
	var _d := s.push(1, 0, &"d")
	s.cancel(a)
	s.reschedule(c, 0)
	var fast = s.peek_next()
	var legacy = _legacy_peek_next(s)
	t.ok(fast != null and legacy != null, "both peeks return an entry")
	t.eq(fast.event_id, legacy.event_id, "fast peek_next equals legacy ordered scan (id)")
	t.eq(fast.due_tick, legacy.due_tick, "fast peek_next equals legacy ordered scan (tick)")


static func _test_drain_avoids_full_copies(t) -> void:
	# Draining a queue with no stale front (plain pop) must not trigger a full
	# ordered() copy per peek_next(): the dominant EQM-142 win.
	var b := CountingBackend.new()
	var s := EQScheduler.new(b)
	var n := 64
	for i in n:
		s.push((i * 2654435761) % n, (i * 40503) % 7, &"turn")
	var peek_ordered_calls := 0
	while not s.is_empty():
		s.pop()
		if not s.is_empty():
			b.ordered_calls = 0
			s.peek_next()
			peek_ordered_calls += b.ordered_calls
	t.eq(peek_ordered_calls, 0, "steady-state drain makes zero full ordered() copies in peek_next")


# Test-only copy of the removed pre-EQM-142 peek_next(): always scans ordered().
static func _legacy_peek_next(s: EQScheduler):
	# GDScript underscore members are convention-private; a test may read them to
	# reproduce the removed code shape against the same live objects.
	for e in s._backend.ordered():
		if s._is_live(e):
			return e
	return null
