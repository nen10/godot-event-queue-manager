extends RefCounted
## EQM-012: scheduler snapshot/restore. Roundtrip reproduces current_tick, the
## sequence/id counters, live entries, generations, and subsequent pop order;
## live-state compaction drops stale entries; unknown schema_version and
## malformed data produce stable load errors leaving the scheduler unchanged.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQSnapshot := preload("res://addons/event_queue_manager/runtime/eq_snapshot.gd")


static func run(t) -> void:
	_test_roundtrip_fidelity(t)
	_test_stale_compaction(t)
	_test_post_restore_operations(t)
	_test_unknown_version_stable_error(t)
	_test_malformed_error(t)


## Drains a scheduler into a flat "id:tick" list (mutates the scheduler).
static func _drain(s) -> Array:
	var out: Array = []
	while not s.is_empty():
		var e = s.pop()
		out.append("%d:%d" % [e.event_id, e.due_tick])
	return out


static func _peek_ids(s) -> Array:
	return s.peek(100).map(func(e): return e.event_id)


static func _test_roundtrip_fidelity(t) -> void:
	var s := EQScheduler.new()
	s.push(8, 0, &"a", &"hero", {"dmg": 3})
	var b := s.push(3)
	var c := s.push(8, 5)
	s.push(1)
	s.pop()                 # consume the front (tick 1), advancing the clock
	s.reschedule(c, 2)      # c jumps ahead; its old entry goes stale, generation -> 1
	s.cancel(b)             # b removed lazily

	var data := s.snapshot()
	t.eq(int(data["schema_version"]), EQSnapshot.SCHEMA_VERSION, "snapshot carries schema_version")
	var tick_at_snapshot: int = s.current_tick

	var s2 := EQScheduler.new()
	t.eq(s2.restore(data), EQSnapshot.Load.OK, "restore of a valid snapshot -> OK")
	t.eq(s2.current_tick, tick_at_snapshot, "restore reproduces current_tick")
	t.eq(s2.size(), s.size(), "restore reproduces live size")

	var order_original := _drain(s)
	var order_restored := _drain(s2)
	t.eq(order_restored, order_original, "restore reproduces subsequent pop order")
	t.ok(order_restored.size() > 0, "roundtrip produced a non-trivial pop order")


static func _test_stale_compaction(t) -> void:
	var s := EQScheduler.new()
	var a := s.push(1)
	var b := s.push(2)
	s.push(3)
	s.cancel(b)             # stale entry remains in backend until popped
	s.reschedule(a, 5)      # original `a` entry now stale too
	var data := s.snapshot()
	# live = a(rescheduled) + the tick-3 event = 2; stale b and old-a are compacted
	t.eq((data["entries"] as Array).size(), 2, "snapshot stores only live entries (stale compacted)")
	t.eq(int(data["next_event_id"]), 4, "snapshot preserves next_event_id counter")

	var s2 := EQScheduler.new()
	s2.restore(data)
	t.ok(not _peek_ids(s2).has(b), "cancelled id absent after restore")
	t.eq(s2.size(), 2, "restored live size excludes stale")


static func _test_post_restore_operations(t) -> void:
	var s := EQScheduler.new()
	var a := s.push(2)
	var keep := s.push(4)
	var data := s.snapshot()

	var s2 := EQScheduler.new()
	s2.restore(data)
	# generation map rebuilt -> cancel/reschedule still target the right entries
	t.ok(s2.cancel(a), "cancel works after restore (generation map rebuilt)")
	t.ok(s2.reschedule(keep, 1), "reschedule works after restore")
	# counters preserved -> a new push continues the id sequence, no collision
	var fresh := s2.push(9)
	t.eq(fresh, int(data["next_event_id"]), "push after restore continues the id counter")
	t.ok(fresh != a and fresh != keep, "restored counter prevents id collision")
	t.eq(s2.pop().event_id, keep, "rescheduled-after-restore event pops first")


static func _test_unknown_version_stable_error(t) -> void:
	var s := EQScheduler.new()
	s.push(1)
	s.push(2)
	var bad := s.snapshot()
	bad["schema_version"] = 999

	var before := _peek_ids(s)
	var code1 := s.restore(bad)
	var code2 := s.restore(bad)
	t.eq(code1, EQSnapshot.Load.UNKNOWN_VERSION, "unknown schema_version -> UNKNOWN_VERSION")
	t.eq(code2, code1, "load error is stable across calls")
	t.eq(_peek_ids(s), before, "scheduler unchanged after unknown-version restore")
	t.eq(s.size(), 2, "size unchanged after failed restore")
	t.eq(EQSnapshot.describe(EQSnapshot.Load.UNKNOWN_VERSION), "unknown snapshot schema_version", "describe maps the code")


static func _test_malformed_error(t) -> void:
	var s := EQScheduler.new()
	s.push(1)
	var before := _peek_ids(s)
	t.eq(s.restore({}), EQSnapshot.Load.MALFORMED, "empty dict -> MALFORMED")
	t.eq(s.restore({"schema_version": EQSnapshot.SCHEMA_VERSION}), EQSnapshot.Load.MALFORMED, "missing structure -> MALFORMED")
	t.eq(s.restore(42), EQSnapshot.Load.MALFORMED, "non-dict -> MALFORMED")
	t.eq(_peek_ids(s), before, "scheduler unchanged after malformed restore")
