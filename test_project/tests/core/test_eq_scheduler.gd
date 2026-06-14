extends RefCounted
## EQM-011: scheduler push/pop/peek/cancel/reschedule, lazy invalidation by
## generation, empty-queue behaviour, and the event-driven clock.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")


static func run(t) -> void:
	_test_push_pop_order(t)
	_test_empty_queue(t)
	_test_peek_non_destructive(t)
	_test_cancel_lazy(t)
	_test_reschedule(t)
	_test_id_sequence_discipline(t)
	_test_current_tick_clock(t)


static func _test_push_pop_order(t) -> void:
	var s := EQScheduler.new()
	# pushed out of order; expect EQOrdering: due asc, priority desc, sequence asc
	var i_late := s.push(5)            # tick 5
	var i_early := s.push(2)           # tick 2
	var i_hi := s.push(2, 10)          # tick 2, priority 10 -> before i_early
	t.ok(i_late > 0 and i_early > 0 and i_hi > 0, "push returns positive event_ids")
	t.eq(s.size(), 3, "size counts live events")
	var order: Array[int] = []
	while not s.is_empty():
		order.append(s.pop().event_id)
	t.eq(order, [i_hi, i_early, i_late], "pop yields EQOrdering total order")
	t.ok(s.pop() == null, "pop on drained queue is null")


static func _test_empty_queue(t) -> void:
	var s := EQScheduler.new()
	t.ok(s.is_empty(), "fresh scheduler is empty")
	t.ok(s.pop() == null, "pop empty -> null")
	t.ok(s.peek_next() == null, "peek_next empty -> null")
	t.eq(s.peek(3), [], "peek(n) empty -> []")
	t.ok(not s.cancel(999), "cancel unknown id -> false")
	t.ok(not s.reschedule(999, 1), "reschedule unknown id -> false")
	t.ok(s.push(-1) == -1, "negative tick rejected -> -1 (expected error line above)")
	t.ok(s.is_empty(), "rejected push leaves queue empty")


static func _test_peek_non_destructive(t) -> void:
	var s := EQScheduler.new()
	var a := s.push(1)
	var b := s.push(2)
	s.push(3)
	t.eq(s.peek_next().event_id, a, "peek_next sees the front")
	t.eq(s.peek(2).map(func(e): return e.event_id), [a, b], "peek(2) sees first two in order")
	t.eq(s.size(), 3, "peek does not remove entries")
	t.eq(s.pop().event_id, a, "pop after peek still returns the front")


static func _test_cancel_lazy(t) -> void:
	var s := EQScheduler.new()
	var a := s.push(1)
	var b := s.push(2)
	var c := s.push(3)
	t.ok(s.cancel(b), "cancel live id -> true")
	t.ok(not s.cancel(b), "double cancel -> false")
	t.eq(s.size(), 2, "size drops after cancel")
	t.eq(s.peek(5).map(func(e): return e.event_id), [a, c], "cancelled id skipped in peek")
	var order: Array[int] = []
	while not s.is_empty():
		order.append(s.pop().event_id)
	t.eq(order, [a, c], "cancelled entry discarded lazily at pop")


static func _test_reschedule(t) -> void:
	var s := EQScheduler.new()
	var a := s.push(10, 0, &"hit", &"hero", {"dmg": 7})
	var b := s.push(5)
	# move `a` ahead of `b`; payload/kind/actor preserved
	t.ok(s.reschedule(a, 1), "reschedule live id -> true")
	t.eq(s.size(), 2, "reschedule keeps live count (not a new event)")
	var first := s.pop()
	t.eq(first.event_id, a, "rescheduled event now pops first")
	t.eq(first.due_tick, 1, "rescheduled to new due_tick")
	t.eq(String(first.kind), "hit", "reschedule preserves kind")
	t.eq(String(first.actor_id), "hero", "reschedule preserves actor_id")
	t.eq(first.payload.get("dmg"), 7, "reschedule preserves payload")
	t.eq(s.pop().event_id, b, "stale pre-reschedule entry discarded; b follows")
	t.ok(s.is_empty(), "no stale entry resurrected")
	# invalid reschedule leaves the event live and unchanged
	var s2 := EQScheduler.new()
	var x := s2.push(4)
	t.ok(not s2.reschedule(x, -3), "reschedule to negative tick rejected (expected error line above)")
	t.eq(s2.pop().due_tick, 4, "rejected reschedule leaves original due_tick")


static func _test_id_sequence_discipline(t) -> void:
	var s := EQScheduler.new()
	var a := s.push(1)
	t.ok(s.push(-5) == -1, "rejected push -> -1 (expected error line above)")
	var b := s.push(1)
	t.eq(b, a + 1, "rejected push consumes no event_id (next id is contiguous)")
	s.cancel(a)
	var c := s.push(1)
	t.ok(c != a and c > b, "cancelled event_id is never reused")


static func _test_current_tick_clock(t) -> void:
	var s := EQScheduler.new()
	t.eq(s.current_tick, 0, "clock starts at 0")
	s.push(3)
	s.push(7)
	s.push(7)
	s.pop()
	t.eq(s.current_tick, 3, "clock advances to popped due_tick")
	s.pop()
	t.eq(s.current_tick, 7, "clock advances forward")
	s.pop()
	t.eq(s.current_tick, 7, "clock never moves backward at equal tick")
