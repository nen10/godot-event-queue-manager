class_name EQOrdering
extends RefCounted
## Deterministic total order over EQEntry: due_tick ASC, priority DESC, sequence ASC.
##
## sequence is unique per push, so the order is total: no two distinct entries
## ever compare equal, and the result is independent of sort stability. This is
## the core determinism guarantee (DETERMINISM_TRACE_TEST_POLICY).

const EQEntry = preload("res://addons/event_queue_manager/runtime/eq_entry.gd")


static func less_than(a: EQEntry, b: EQEntry) -> bool:
	if a.due_tick != b.due_tick:
		return a.due_tick < b.due_tick
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.sequence < b.sequence


static func sort(entries: Array) -> void:
	entries.sort_custom(less_than)
