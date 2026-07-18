class_name EQTriggerIndex
extends RefCounted
## Derived acceleration index for armed reactions (EQM-102/EQM-136). The trigger
## engine keeps the canonical armed table; this non-serialized index only narrows
## `condition.matches()` calls to the resolving target bucket plus wildcards.
##
## The index is a candidate FILTER, not a replacement for matches(): `match_target`
## is the bucket key; the remaining condition fields (tags, kind, source) are still
## checked by the caller via condition.matches(view). `candidates(view)` returns the
## entries in ARM order, so applying matches() to them yields the same fired set and
## order as the linear engine — verified by the parity benchmark.

# entry: { reservation, condition, seq, bucket_target }
var _by_target: Dictionary = {}   # StringName -> Array[Dictionary]
var _wildcard: Array = []         # conditions with empty match_target
var _by_sequence: Dictionary = {} # int -> entry
# condition instance id -> { condition, callback, sequences }
var _condition_bindings: Dictionary = {}
var _seq: int = 0


## Index an armed reaction. Returns its arm sequence (stable ordering key).
func add(reservation, condition) -> int:
	var target: StringName = condition.match_target if condition != null else &""
	var entry := {
		"reservation": reservation,
		"condition": condition,
		"seq": _seq,
		"bucket_target": target,
	}
	_seq += 1
	_by_sequence[entry["seq"]] = entry
	_append_to_bucket(entry, target)
	_register_condition(condition, int(entry["seq"]))
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
	return _by_sequence.size()


func target_bucket_size(target: StringName) -> int:
	return (_by_target[target] as Array).size() if _by_target.has(target) else 0


func wildcard_size() -> int:
	return _wildcard.size()


func clear() -> void:
	for binding in _condition_bindings.values():
		var condition = binding["condition"]
		var callback: Callable = binding["callback"]
		if condition != null and condition.changed.is_connected(callback):
			condition.changed.disconnect(callback)
	_by_target.clear()
	_wildcard.clear()
	_by_sequence.clear()
	_condition_bindings.clear()
	_seq = 0


## Removes one exact arm slot. Sequence, not reservation identity, is the slot
## key because the same reservation object may be armed more than once.
func _remove_sequence(sequence: int) -> bool:
	if not _by_sequence.has(sequence):
		return false
	var entry: Dictionary = _by_sequence[sequence]
	_remove_from_bucket(entry)
	_unregister_condition(entry["condition"], sequence)
	_by_sequence.erase(sequence)
	return true


func _append_to_bucket(entry: Dictionary, target: StringName) -> void:
	entry["bucket_target"] = target
	if target == &"":
		_wildcard.append(entry)
		return
	if not _by_target.has(target):
		_by_target[target] = []
	(_by_target[target] as Array).append(entry)


func _remove_from_bucket(entry: Dictionary) -> void:
	var target: StringName = entry.get("bucket_target", &"")
	var sequence := int(entry["seq"])
	if target == &"":
		_erase_sequence_from_array(_wildcard, sequence)
		return
	if not _by_target.has(target):
		return
	var bucket: Array = _by_target[target]
	_erase_sequence_from_array(bucket, sequence)
	if bucket.is_empty():
		_by_target.erase(target)


func _erase_sequence_from_array(entries: Array, sequence: int) -> void:
	for i in range(entries.size()):
		if int(entries[i]["seq"]) == sequence:
			entries.remove_at(i)
			return


func _register_condition(condition, sequence: int) -> void:
	if condition == null:
		return
	var condition_id := int(condition.get_instance_id())
	if not _condition_bindings.has(condition_id):
		var callback := Callable(self, "_on_condition_changed").bind(condition_id)
		condition.changed.connect(callback)
		_condition_bindings[condition_id] = {
			"condition": condition,
			"callback": callback,
			"sequences": [],
		}
	var sequences: Array = _condition_bindings[condition_id]["sequences"]
	sequences.append(sequence)


func _unregister_condition(condition, sequence: int) -> void:
	if condition == null:
		return
	var condition_id := int(condition.get_instance_id())
	if not _condition_bindings.has(condition_id):
		return
	var binding: Dictionary = _condition_bindings[condition_id]
	var sequences: Array = binding["sequences"]
	sequences.erase(sequence)
	if not sequences.is_empty():
		return
	var callback: Callable = binding["callback"]
	if condition.changed.is_connected(callback):
		condition.changed.disconnect(callback)
	_condition_bindings.erase(condition_id)


func _on_condition_changed(condition_id: int) -> void:
	if not _condition_bindings.has(condition_id):
		return
	var binding: Dictionary = _condition_bindings[condition_id]
	var condition = binding["condition"]
	var target: StringName = condition.match_target if condition != null else &""
	# A condition may own several arm slots. Rebucket each slot without changing
	# its sequence so global arm order remains stable.
	for sequence in (binding["sequences"] as Array).duplicate():
		var seq := int(sequence)
		if not _by_sequence.has(seq):
			continue
		var entry: Dictionary = _by_sequence[seq]
		if entry.get("bucket_target", &"") == target:
			continue
		_remove_from_bucket(entry)
		_append_to_bucket(entry, target)
