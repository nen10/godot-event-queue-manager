class_name EQEffectChunk
extends RefCounted
## The effect-processing-chunk: EffectRecords accumulate here as events resolve.
## A save is allowed exactly when the chunk is empty (EVENT_MODEL_SEMANTICS
## §10/§22) — appended at resolution, drained at the save/sync boundary. This is
## the concrete mechanism behind "save boundary = empty effect-processing-chunk".

const EQEffectRecord := preload("eq_effect_record.gd")

var _records: Array[EQEffectRecord] = []


func add(record: EQEffectRecord) -> void:
	_records.append(record)


func records() -> Array:
	return _records.duplicate()


func size() -> int:
	return _records.size()


func is_empty() -> bool:
	return _records.is_empty()


## A save is allowed only at a chunk boundary — i.e. when no effect is pending.
func is_save_allowed() -> bool:
	return _records.is_empty()


func clear() -> void:
	_records.clear()


## Returns the accumulated records and empties the chunk (the save/sync boundary
## transition).
func drain() -> Array:
	var out := _records.duplicate()
	_records.clear()
	return out
