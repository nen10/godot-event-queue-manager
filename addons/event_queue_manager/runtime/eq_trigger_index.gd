class_name EQTriggerIndex
extends RefCounted
## Acceleration index for armed reactions (EQM-102). EQTriggerEngine.on_event_resolved
## linearly scans every armed reaction (O(armed)) calling condition.matches per
## event. This index buckets armed reactions by their condition's `match_target`
## (plus a wildcard bucket for target-agnostic conditions), so a resolving event
## only reconsiders the reactions that could possibly match its target —
## O(target bucket + wildcards) instead of O(all armed).
##
## The index is a candidate FILTER, not a replacement for matches(): `match_target`
## is the bucket key; the remaining condition fields (tags, kind, source) are still
## checked by the caller via condition.matches(view). `candidates(view)` returns the
## entries in ARM order, so applying matches() to them yields the same fired set and
## order as the linear engine — verified by the parity benchmark.

# entry: { reservation, condition, seq }
var _by_target: Dictionary = {}   # StringName -> Array[Dictionary]
var _wildcard: Array = []         # conditions with empty match_target
var _seq: int = 0


## Index an armed reaction. Returns its arm sequence (stable ordering key).
func add(reservation, condition) -> int:
	var entry := {"reservation": reservation, "condition": condition, "seq": _seq}
	_seq += 1
	var target: StringName = condition.match_target if condition != null else &""
	if target == &"":
		_wildcard.append(entry)
	else:
		if not _by_target.has(target):
			_by_target[target] = []
		(_by_target[target] as Array).append(entry)
	return entry["seq"]


## Candidate reactions for a resolving event view, in arm order: those bucketed on
## the view's target, plus the target-agnostic wildcards. The caller applies
## condition.matches(view) to these (a strict subset of all armed) to fire.
func candidates(view: Dictionary) -> Array:
	var target: StringName = view.get("target", &"")
	var out: Array = []
	if _by_target.has(target):
		out.append_array(_by_target[target])
	out.append_array(_wildcard)
	out.sort_custom(func(a, b): return int(a["seq"]) < int(b["seq"]))
	return out


## Reservations whose conditions match the view, in arm order (candidates filtered
## by matches()). Equivalent to the linear engine's fired set, computed over the
## candidate subset only.
func matching_reservations(view: Dictionary) -> Array:
	var out: Array = []
	for entry in candidates(view):
		var cond = entry["condition"]
		if cond != null and cond.matches(view):
			out.append(entry["reservation"])
	return out


func size() -> int:
	return _seq_count()


func target_bucket_size(target: StringName) -> int:
	return (_by_target[target] as Array).size() if _by_target.has(target) else 0


func wildcard_size() -> int:
	return _wildcard.size()


func clear() -> void:
	_by_target.clear()
	_wildcard.clear()
	_seq = 0


func _seq_count() -> int:
	var n := _wildcard.size()
	for k in _by_target.keys():
		n += (_by_target[k] as Array).size()
	return n
