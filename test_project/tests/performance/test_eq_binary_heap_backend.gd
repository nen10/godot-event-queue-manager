extends RefCounted
## EQM-102 / EQM-136 — explicit-lane throughput guard for the binary heap.
## Ordering, non-mutation, and scheduler-swap correctness live in the regression
## suite at res://tests/core/test_eq_binary_heap_backend.gd.

const EQEntry := preload("res://addons/event_queue_manager/runtime/eq_entry.gd")
const EQHeap := preload("res://addons/event_queue_manager/runtime/backends/eq_binary_heap_backend.gd")

const BUDGET_N := 10000
const BUDGET_MS := 2000


static func run(t) -> void:
	_test_throughput_budget(t)


# A deterministic, collision-free sequence of entries (unique sequence => total order).
static func _entry(i: int) -> EQEntry:
	var tick := (i * 2654435761) % 1000          # pseudo-random ticks with many ties
	var priority := (i * 40503) % 7               # ties within a tick
	return EQEntry.make(i + 1, tick, priority, i, &"turn", StringName("a%d" % i))


static func _test_throughput_budget(t) -> void:
	var heap := EQHeap.new()
	var start := Time.get_ticks_msec()
	for i in BUDGET_N:
		heap.insert(_entry(i))
	var popped := 0
	while not heap.is_empty():
		heap.pop_min()
		popped += 1
	var elapsed := Time.get_ticks_msec() - start
	t.eq(popped, BUDGET_N, "heap throughput fixture processes the declared entry count")
	t.ok(elapsed < BUDGET_MS, "heap %d insert+pop within budget: %d ms < %d ms" % [BUDGET_N, elapsed, BUDGET_MS])
