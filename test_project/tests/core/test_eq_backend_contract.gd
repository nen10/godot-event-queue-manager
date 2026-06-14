extends RefCounted
## EQM-011: the scheduler depends only on the EQBackend contract, not on any
## one backend's internals. A genuinely different backend (unsorted storage,
## scan-for-min) driven through the same scenario must produce an identical
## pop/peek trace as the default sorted-array backend (metamorphic equivalence).
## This is what "swappable without a public API change" means in practice.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQOrdering := preload("res://addons/event_queue_manager/runtime/eq_ordering.gd")


## A deliberately naive EQBackend: append unsorted, find the minimum by scanning.
## Correct but structurally unlike the sorted array, so equal results isolate the
## scheduler's behaviour from storage strategy.
class NaiveBackend extends EQBackend:
	var _items: Array[EQEntry] = []

	func insert(entry: EQEntry) -> void:
		_items.append(entry)

	func _min_index() -> int:
		var best := -1
		for i in _items.size():
			if best == -1 or EQOrdering.less_than(_items[i], _items[best]):
				best = i
		return best

	func pop_min() -> EQEntry:
		var i := _min_index()
		if i == -1:
			return null
		var e := _items[i]
		_items.remove_at(i)
		return e

	func peek_min() -> EQEntry:
		var i := _min_index()
		return null if i == -1 else _items[i]

	func ordered() -> Array:
		var copy := _items.duplicate()
		EQOrdering.sort(copy)
		return copy

	func size() -> int:
		return _items.size()

	func is_empty() -> bool:
		return _items.is_empty()

	func clear() -> void:
		_items.clear()


static func run(t) -> void:
	var trace_default := _scenario(EQScheduler.new())
	var trace_naive := _scenario(EQScheduler.new(NaiveBackend.new()))
	t.eq(trace_naive, trace_default, "naive backend yields identical scheduler trace as sorted-array")
	# sanity: the scenario actually exercised ordering, not an empty run
	t.ok(trace_default.size() > 5, "scenario produced a non-trivial trace")


## Runs a fixed mix of push/peek/cancel/reschedule/pop and records observable
## results as a flat array of strings (backend-agnostic).
static func _scenario(s: EQScheduler) -> Array:
	var log: Array = []
	var a := s.push(8, 0, &"a")
	var b := s.push(3, 0, &"b")
	var c := s.push(8, 5, &"c")   # same tick as a, higher priority
	var d := s.push(1, 0, &"d")
	log.append("size=%d" % s.size())
	log.append("peek=%s" % str(s.peek(3).map(func(e): return e.event_id)))
	s.cancel(b)
	s.reschedule(c, 0)            # c moves to the very front
	log.append("size=%d" % s.size())
	while not s.is_empty():
		var e = s.pop()
		log.append("pop id=%d tick=%d tick_clock=%d" % [e.event_id, e.due_tick, s.current_tick])
	log.append("final=%s" % str(s.pop()))
	# reference the ids so the analyzer keeps them; also documents intent
	log.append("ids=%d,%d,%d,%d" % [a, b, c, d])
	return log
