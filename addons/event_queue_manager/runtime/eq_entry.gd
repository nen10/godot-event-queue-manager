class_name EQEntry
extends RefCounted
## A scheduled event entry.
##
## The ordering keys (due_tick, priority, sequence) form a deterministic total
## order via EQOrdering. Keys are immutable after creation: rescheduling is
## cancel + re-push (DETERMINISM_TRACE_TEST_POLICY; EVENT_MODEL_OPEN_QUESTIONS
## Q07/Q08). `generation` is scheduler-internal for lazy invalidation and is
## NOT an ordering key.

var event_id: int = 0
var due_tick: int = 0
var priority: int = 0
var sequence: int = 0
var generation: int = 0
var kind: StringName = &""
var actor_id: StringName = &""
var payload: Dictionary = {}


## Constructs an entry, or returns null when the tick is invalid (negative).
## Returning null is an explicit rejection (the caller must handle it), not a
## silent fallback. The scheduler surfaces this per RUNTIME_RESILIENCE_POLICY
## (dev fail-fast / shipped fail-safe); EQM-020 folds it into the error taxonomy.
static func make(event_id: int, due_tick: int, priority: int, sequence: int, kind: StringName = &"", actor_id: StringName = &"", payload: Dictionary = {}) -> EQEntry:
	if due_tick < 0:
		return null
	var e := EQEntry.new()
	e.event_id = event_id
	e.due_tick = due_tick
	e.priority = priority
	e.sequence = sequence
	e.kind = kind
	e.actor_id = actor_id
	e.payload = payload
	return e


func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"due_tick": due_tick,
		"priority": priority,
		"sequence": sequence,
		"generation": generation,
		"kind": String(kind),
		"actor_id": String(actor_id),
		"payload": payload,
	}


static func from_dict(d: Dictionary) -> EQEntry:
	var e := make(int(d["event_id"]), int(d["due_tick"]), int(d["priority"]), int(d["sequence"]), StringName(d.get("kind", "")), StringName(d.get("actor_id", "")), d.get("payload", {}))
	if e != null:
		e.generation = int(d.get("generation", 0))
	return e
