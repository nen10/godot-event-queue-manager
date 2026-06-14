class_name EQSortedArrayBackend
extends EQBackend
## EQBackend implemented as an array kept sorted by EQOrdering.
##
## insert is O(n) (binary search for the slot, then shift); pop_min is O(n)
## (pop_front shifts). This is the MVP backend: simple and obviously correct.
## A binary-heap backend (EQM-102) replaces it for large queues without any
## public API change, because both honour the EQBackend contract.

const EQOrdering := preload("../eq_ordering.gd")

var _entries: Array[EQEntry] = []


func insert(entry: EQEntry) -> void:
	# bsearch_custom with EQOrdering.less_than returns the first index where the
	# element is not strictly less than `entry`, i.e. the sorted insertion slot.
	var idx := _entries.bsearch_custom(entry, EQOrdering.less_than, true)
	_entries.insert(idx, entry)


func pop_min() -> EQEntry:
	if _entries.is_empty():
		return null
	return _entries.pop_front()


func peek_min() -> EQEntry:
	if _entries.is_empty():
		return null
	return _entries[0]


func ordered() -> Array:
	return _entries.duplicate()


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func clear() -> void:
	_entries.clear()
