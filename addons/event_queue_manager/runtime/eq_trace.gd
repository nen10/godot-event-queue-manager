class_name EQTrace
extends RefCounted
## Canonical trace of resolved events: the machine-checkable proof of ordering,
## which is the addon's central product value (DETERMINISM_TRACE_TEST_POLICY).
##
## One resolved event = one record = one JSONL line. Records carry a resolution
## index `i`, the int ordering keys (tick/priority/seq), identity, kind, actor,
## cause, and a structured `tie_break` (explanation-as-data, not free-form
## prose). Serialization is canonical: keys are sorted recursively so output is
## byte-identical for identical input and has a fixed key order, and arbitrary
## record shapes stay deterministic. This is what makes the record-kind schema
## open: later phases add kinds (event_line_progressed, window_opened/closed,
## invalidation closed_by) by passing new fields — no change here.
##
## Floats are invalid in a canonical trace (ordering keys are int only); the
## encoder treats one as a determinism bug and fails fast in dev. Wall-clock,
## node paths and object addresses must never enter a record.

var _records: Array[Dictionary] = []


## Appends a record of any kind. The `i` resolution index is assigned here and
## always present. Callers supply the remaining fields; the kind set is open.
func record(fields: Dictionary) -> void:
	var r := fields.duplicate(true)
	r["i"] = _records.size()
	_records.append(r)


## Convenience for the common case: a resolved scheduler event. `cause` is one of
## timer | trigger:<tag> | rumination | operation | wait | ready (timer at this
## phase). `decided_by` is the ordering key that placed this event before the
## next one.
func record_resolved(entry: EQEntry, cause: String, decided_by: String) -> void:
	record({
		"tick": entry.due_tick,
		"seq": entry.sequence,
		"priority": entry.priority,
		"event_id": entry.event_id,
		"kind": "resolved",
		"actor": String(entry.actor_id),
		"cause": cause,
		"tie_break": {
			"compared": ["due_tick", "priority", "sequence"],
			"decided_by": decided_by,
		},
	})


func size() -> int:
	return _records.size()


## Deep copy of the records (read-only inspection / property comparison).
func records() -> Array:
	return _records.duplicate(true)


## Canonical JSONL: one record per line, keys sorted recursively. Byte-identical
## for identical input.
func to_jsonl() -> String:
	var lines := PackedStringArray()
	for r in _records:
		lines.append(_encode(r))
	return "\n".join(lines)


## Resolves a scheduler to exhaustion into a canonical trace. `decided_by` for
## each event is computed against the next live event (terminal for the last).
static func trace_run(scheduler) -> EQTrace:
	var tr := EQTrace.new()
	while not scheduler.is_empty():
		var e: EQEntry = scheduler.pop()
		var nxt: EQEntry = scheduler.peek_next()
		tr.record_resolved(e, "timer", _decided_by(e, nxt))
	return tr


static func _decided_by(e: EQEntry, nxt: EQEntry) -> String:
	if nxt == null:
		return "terminal"
	if e.due_tick != nxt.due_tick:
		return "due_tick"
	if e.priority != nxt.priority:
		return "priority"
	return "sequence"


static func _encode(v) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var keys := (v as Dictionary).keys()
			keys.sort()
			var parts := PackedStringArray()
			for k in keys:
				parts.append("%s:%s" % [_encode_str(String(k)), _encode(v[k])])
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for e in v:
				parts.append(_encode(e))
			return "[" + ",".join(parts) + "]"
		TYPE_STRING, TYPE_STRING_NAME:
			return _encode_str(String(v))
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			# Ordering keys are int only; a float in a canonical trace is a
			# determinism bug, surfaced (dev fail-fast) rather than silently
			# formatted.
			push_error("EQTrace: float is invalid in a canonical trace: %s" % str(v))
			return str(v)
		TYPE_NIL:
			return "null"
		_:
			push_error("EQTrace: unsupported trace value type %d" % typeof(v))
			return "null"


static func _encode_str(s: String) -> String:
	return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
