class_name EQBinaryHeapBackend
extends EQBackend
## EQBackend implemented as a binary min-heap ordered by EQOrdering (EQM-102).
##
## insert and pop_min are O(log n) (sift up / down); peek_min is O(1). This
## replaces the sorted-array backend's O(n) insert/pop for large queues with NO
## public API change — both honour the EQBackend contract, and because EQOrdering
## is a *total* order (sequence is unique), the heap's pop sequence is identical,
## entry-for-entry, to the sorted-array backend's. It is opt-in:
## `EQScheduler.new(EQBinaryHeapBackend.new())`; the default stays sorted-array.
##
## `ordered()` must not mutate the heap, so it sorts a copy (O(n log n)); the heap
## array itself is only partially ordered.

const EQOrdering := preload("../eq_ordering.gd")

var _heap: Array[EQEntry] = []


func insert(entry: EQEntry) -> void:
	_heap.append(entry)
	_sift_up(_heap.size() - 1)


func pop_min() -> EQEntry:
	if _heap.is_empty():
		return null
	var top := _heap[0]
	var last := _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		_sift_down(0)
	return top


func peek_min() -> EQEntry:
	if _heap.is_empty():
		return null
	return _heap[0]


func ordered() -> Array:
	# Non-mutating: the heap array is only partially ordered, so sort a copy.
	var copy := _heap.duplicate()
	copy.sort_custom(EQOrdering.less_than)
	return copy


func size() -> int:
	return _heap.size()


func is_empty() -> bool:
	return _heap.is_empty()


func clear() -> void:
	_heap.clear()


func _sift_up(i: int) -> void:
	while i > 0:
		var parent := (i - 1) >> 1
		if EQOrdering.less_than(_heap[i], _heap[parent]):
			_swap(i, parent)
			i = parent
		else:
			break


func _sift_down(i: int) -> void:
	var n := _heap.size()
	while true:
		var left := 2 * i + 1
		var right := 2 * i + 2
		var smallest := i
		if left < n and EQOrdering.less_than(_heap[left], _heap[smallest]):
			smallest = left
		if right < n and EQOrdering.less_than(_heap[right], _heap[smallest]):
			smallest = right
		if smallest == i:
			break
		_swap(i, smallest)
		i = smallest


func _swap(a: int, b: int) -> void:
	var tmp := _heap[a]
	_heap[a] = _heap[b]
	_heap[b] = tmp
