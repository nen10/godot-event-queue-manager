extends RefCounted
## EQM-102 — the binary-heap backend is order-identical to the sorted-array backend
## (the hard gate) and stays within the declared per-advance budget (a coarse
## regression guard). Budgets are declared in
## docs/plan/.../EQM-102_performance_backend/SUB_TASKS.md.

const EQEntry := preload("res://addons/event_queue_manager/runtime/eq_entry.gd")
const EQHeap := preload("res://addons/event_queue_manager/runtime/backends/eq_binary_heap_backend.gd")
const EQSorted := preload("res://addons/event_queue_manager/runtime/backends/eq_sorted_array_backend.gd")
const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")

const ORDER_N := 5000
const BUDGET_N := 10000
const BUDGET_MS := 2000


static func run(t) -> void:
	_test_order_identical_to_sorted_array(t)
	_test_ordered_is_non_mutating(t)
	_test_scheduler_backend_swap_no_api_change(t)
	_test_throughput_budget(t)


# A deterministic, collision-free sequence of entries (unique sequence => total order).
static func _entry(i: int) -> EQEntry:
	var tick := (i * 2654435761) % 1000          # pseudo-random ticks with many ties
	var priority := (i * 40503) % 7               # ties within a tick
	return EQEntry.make(i + 1, tick, priority, i, &"turn", StringName("a%d" % i))


static func _test_order_identical_to_sorted_array(t) -> void:
	var heap := EQHeap.new()
	var sorted := EQSorted.new()
	for i in ORDER_N:
		var e := _entry(i)
		heap.insert(e)
		sorted.insert(_entry(i))  # an equal-keyed twin (same event_id/tick/priority/sequence)
	t.eq(heap.size(), ORDER_N, "heap holds every inserted entry")

	var mismatch := -1
	for i in ORDER_N:
		var h := heap.pop_min()
		var s := sorted.pop_min()
		if h == null or s == null or h.event_id != s.event_id:
			mismatch = i
			break
	t.eq(mismatch, -1, "heap pop sequence is identical to sorted-array, entry-for-entry (%d entries)" % ORDER_N)
	t.ok(heap.is_empty(), "heap drained")


static func _test_ordered_is_non_mutating(t) -> void:
	var heap := EQHeap.new()
	for i in 50:
		heap.insert(_entry(i))
	var a := heap.ordered()
	var b := heap.ordered()
	t.eq(heap.size(), 50, "ordered() did not mutate the heap")
	t.eq(a.size(), 50, "ordered() returns every entry")
	var sorted_ok := true
	for i in range(1, a.size()):
		# strictly increasing in EQOrdering => a[i-1] < a[i]
		if not (a[i - 1].due_tick < a[i].due_tick
			or (a[i - 1].due_tick == a[i].due_tick and a[i - 1].priority > a[i].priority)
			or (a[i - 1].due_tick == a[i].due_tick and a[i - 1].priority == a[i].priority and a[i - 1].sequence < a[i].sequence)):
			sorted_ok = false
			break
	t.ok(sorted_ok, "ordered() is in EQOrdering order")
	t.eq(a[0].event_id, b[0].event_id, "ordered() is stable across calls")


static func _test_scheduler_backend_swap_no_api_change(t) -> void:
	# The scheduler takes any EQBackend; swapping to the heap changes nothing public.
	var s := EQScheduler.new(EQHeap.new())
	s.push(10, 0, &"atk", &"hero")
	s.push(4, 0, &"move", &"hero")
	s.push(10, 5, &"atk", &"orc")
	t.eq(s.pop().actor_id, &"hero", "heap-backed scheduler pops the earliest (move @4) first")
	t.eq(s.pop().actor_id, &"orc", "then tick-10 priority DESC: orc (pri 5) before hero (pri 0)")
	t.ok(s.pop() != null and s.is_empty(), "last entry pops, queue drains")


static func _test_throughput_budget(t) -> void:
	var heap := EQHeap.new()
	var start := Time.get_ticks_msec()
	for i in BUDGET_N:
		heap.insert(_entry(i))
	while not heap.is_empty():
		heap.pop_min()
	var elapsed := Time.get_ticks_msec() - start
	t.ok(elapsed < BUDGET_MS, "heap %d insert+pop within budget: %d ms < %d ms" % [BUDGET_N, elapsed, BUDGET_MS])
