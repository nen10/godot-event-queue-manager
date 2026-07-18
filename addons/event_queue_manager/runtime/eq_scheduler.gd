class_name EQScheduler
extends RefCounted
## Deterministic event scheduler: push/pop/peek/cancel/reschedule over an
## EQBackend, with lazy invalidation by generation.
##
## The scheduler owns event identity, the insertion sequence, liveness and the
## event-driven clock; the backend owns only ordered storage. Cancel and
## reschedule resolve the target live event in O(1) via the generation map and
## the event_id -> live-entry accelerator (EQM-143); cancel touches only those
## maps. Reschedule additionally inserts the new entry into the backend
## (O(log n) on the heap, O(n) on the sorted array). A cancelled or superseded
## entry stays in the backend until it surfaces at pop, then is discarded (lazy
## invalidation), so neither cancel nor reschedule scans/copies the backend to
## find the current entry, including on a future binary heap.
##
## Liveness is generation-based (not object identity), so it survives the
## EQM-012 snapshot roundtrip: an entry is live iff its generation equals the
## scheduler's current generation for that event_id.

const EQEntry := preload("eq_entry.gd")
const EQBackend := preload("backends/eq_backend.gd")
const EQSortedArrayBackend := preload("backends/eq_sorted_array_backend.gd")
const EQSnapshot := preload("eq_snapshot.gd")

## Event-driven clock. Advances to a popped entry's due_tick, never backwards.
var current_tick: int = 0

var _backend: EQBackend
# event_id -> current live generation. Its key set is exactly the live event_ids,
# so size() == _generation.size().
var _generation: Dictionary = {}
# event_id -> current live EQEntry. Private accelerator mirrored with
# _generation; the backend may still contain stale cancelled/rescheduled entries.
var _live_entries: Dictionary = {}
var _next_event_id: int = 1
var _next_sequence: int = 0


func _init(backend: EQBackend = null) -> void:
	_backend = backend if backend != null else EQSortedArrayBackend.new()


## Schedules an event. Returns the assigned event_id (>= 1), or -1 when the tick
## is invalid (negative). A rejected push consumes no id or sequence: this is an
## explicit rejection, not a silent fallback (UX_PATH_REDUCTION_POLICY).
func push(due_tick: int, priority: int = 0, kind: StringName = &"", actor_id: StringName = &"", payload: Dictionary = {}) -> int:
	var event_id := _next_event_id
	var entry := EQEntry.make(event_id, due_tick, priority, _next_sequence, kind, actor_id, payload)
	if entry == null:
		return -1
	entry.generation = 0
	_generation[event_id] = 0
	_live_entries[event_id] = entry
	_next_event_id += 1
	_next_sequence += 1
	_backend.insert(entry)
	return event_id


## Removes and returns the next live entry in EQOrdering order, or null when no
## live entry remains. Stale entries surfacing first are discarded here (lazy
## invalidation). Advances current_tick to the returned entry's due_tick.
func pop() -> EQEntry:
	while not _backend.is_empty():
		var e := _backend.pop_min()
		if _is_live(e):
			_generation.erase(e.event_id)
			_live_entries.erase(e.event_id)
			current_tick = maxi(current_tick, e.due_tick)
			return e
		# stale (cancelled or superseded by reschedule): discard
	return null


## Returns the next live entry without removing it, or null.
func peek_next() -> EQEntry:
	# Fast path: EQOrdering is a total order, so the backend minimum is the next
	# entry in pop order. When it is live (the steady-state case) it is exactly
	# the next live entry, answered in O(1) via peek_min() with no full-backend
	# copy/sort. This matters because advance() calls peek_next() for every
	# resolved event's trace `decided_by`; the old unconditional ordered() copy
	# made draining O(n^2) on the sorted-array backend and O(n^2 log n) on the
	# binary heap (ordered() sorts a copy). Semantics are unchanged (EQM-142).
	var m := _backend.peek_min()
	if m != null and _is_live(m):
		return m
	# Stale-front fallback: the minimum is a cancelled/rescheduled artifact, so
	# scan ordered entries for the first live one (lazy invalidation preserved).
	for e in _backend.ordered():
		if _is_live(e):
			return e
	return null


## Returns up to n live entries in EQOrdering order without mutating the queue.
func peek(n: int) -> Array[EQEntry]:
	var out: Array[EQEntry] = []
	if n <= 0:
		return out
	for e in _backend.ordered():
		if _is_live(e):
			out.append(e)
			if out.size() >= n:
				break
	return out


## Cancels a live event by id. Returns true if it was live, false for unknown or
## already-cancelled ids. The backend entry is left for lazy discard at pop.
func cancel(event_id: int) -> bool:
	if not _generation.has(event_id):
		return false
	_generation.erase(event_id)
	_live_entries.erase(event_id)
	return true


## Reschedules a live event: same event_id, new ordering keys, fresh sequence,
## bumped generation (the old entry becomes stale). This is the only sanctioned
## way to change an event's due_tick (EVENT_MODEL: due_tick rewrite forbidden,
## reschedule-only). Fields not overridden (kind/actor/payload, and priority when
## new_priority is null) are preserved. Returns false for unknown ids or an
## invalid new tick (in which case the event stays live and unchanged).
func reschedule(event_id: int, new_due_tick: int, new_priority = null) -> bool:
	if not _generation.has(event_id):
		return false
	var cur := _find_live(event_id)
	if cur == null:
		return false
	var pr: int = cur.priority if new_priority == null else int(new_priority)
	var entry := EQEntry.make(event_id, new_due_tick, pr, _next_sequence, cur.kind, cur.actor_id, cur.payload)
	if entry == null:
		return false
	var new_gen := int(_generation[event_id]) + 1
	entry.generation = new_gen
	_generation[event_id] = new_gen
	_live_entries[event_id] = entry
	_next_sequence += 1
	_backend.insert(entry)
	return true


## Number of live (schedulable) events.
func size() -> int:
	return _generation.size()


## True when no live event remains (stale backend entries do not count).
func is_empty() -> bool:
	return _generation.is_empty()


## Captures live scheduler state as a plain, serializable Dictionary (no Node
## references). Only live entries are stored: stale lazy-deletion artifacts carry
## no observable semantics, so the snapshot compacts them away. Counters and the
## clock are stored explicitly (they cannot be derived from live entries alone,
## since they reflect popped/cancelled events too).
func snapshot() -> Dictionary:
	var entries: Array = []
	for e in _backend.ordered():
		if _is_live(e):
			entries.append(e.to_dict())
	return {
		"schema_version": EQSnapshot.SCHEMA_VERSION,
		"current_tick": current_tick,
		"next_event_id": _next_event_id,
		"next_sequence": _next_sequence,
		"entries": entries,
	}


## Restores state from a snapshot Dictionary. Returns an EQSnapshot.Load code.
## On any non-OK code the scheduler is left exactly as it was (validate and the
## entry rebuild happen before any mutation). On OK, the generation map is
## rebuilt from the entries, re-establishing the liveness invariant by
## construction.
func restore(data) -> int:
	var code := EQSnapshot.validate(data)
	if code != EQSnapshot.Load.OK:
		return code
	# Build off to the side first so a malformed entry cannot half-apply.
	var rebuilt: Array[EQEntry] = []
	for d in data["entries"]:
		var e := EQEntry.from_dict(d)
		if e == null:
			return EQSnapshot.Load.MALFORMED
		rebuilt.append(e)
	# Commit.
	_backend.clear()
	_generation.clear()
	_live_entries.clear()
	current_tick = int(data["current_tick"])
	_next_event_id = int(data["next_event_id"])
	_next_sequence = int(data["next_sequence"])
	for e in rebuilt:
		_generation[e.event_id] = e.generation
		_live_entries[e.event_id] = e
		_backend.insert(e)
	return EQSnapshot.Load.OK


func _is_live(entry: EQEntry) -> bool:
	return _generation.get(entry.event_id, -1) == entry.generation


func _find_live(event_id: int) -> EQEntry:
	var e = _live_entries.get(event_id, null)
	if e != null and _is_live(e):
		return e
	return null
