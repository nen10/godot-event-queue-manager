extends RefCounted
## EQM-010: core ordering contract — due_tick ASC, priority DESC, sequence ASC,
## total order under any insertion permutation, and negative-tick rejection.

const EQEntry := preload("res://addons/event_queue_manager/runtime/eq_entry.gd")
const EQOrdering := preload("res://addons/event_queue_manager/runtime/eq_ordering.gd")


static func run(t) -> void:
	# pairwise key precedence
	t.ok(EQOrdering.less_than(EQEntry.make(2, 3, 0, 1), EQEntry.make(1, 5, 0, 0)), "lower due_tick first")
	t.ok(EQOrdering.less_than(EQEntry.make(3, 5, 10, 2), EQEntry.make(4, 5, 1, 3)), "higher priority first at equal tick")
	t.ok(EQOrdering.less_than(EQEntry.make(5, 5, 0, 7), EQEntry.make(6, 5, 0, 9)), "lower sequence first at equal tick+priority")

	# deterministic total order, independent of insertion permutation
	var a := EQEntry.make(1, 5, 0, 0)
	var b := EQEntry.make(2, 3, 0, 1)
	var c := EQEntry.make(3, 5, 10, 2)
	var dd := EQEntry.make(4, 5, 1, 3)
	var e := EQEntry.make(5, 5, 0, 7)
	var f := EQEntry.make(6, 5, 0, 9)
	var expected := [2, 3, 4, 1, 5, 6]  # b(t3); then t5: c(p10) dd(p1) a(seq0) e(seq7) f(seq9)

	var arr1: Array = [a, dd, c, b, f, e]
	EQOrdering.sort(arr1)
	t.eq(arr1.map(func(x): return x.event_id), expected, "sorted into deterministic total order")

	var arr2: Array = [f, e, dd, c, b, a]
	EQOrdering.sort(arr2)
	t.eq(arr2.map(func(x): return x.event_id), expected, "permutation invariance")

	# tick validity
	t.ok(EQEntry.make(7, -1, 0, 0) == null, "negative due_tick rejected (expected error line above)")
	t.ok(EQEntry.make(8, 0, 0, 0) != null, "zero due_tick allowed")
