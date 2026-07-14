class_name EQEffectCommitResult
extends RefCounted
## Versioned value returned by a transactional named effect handler.
##
## SUCCESS carries the records to append and the ordered serializable event
## views to expose to one outer reaction sweep. FAILURE carries only a
## consumer-owned diagnostic: it contributes no records and requests no sweep.
## The value is deliberately game-vocabulary-neutral; adapters own the meaning
## of every record, event-view field, and diagnostic field.

const EQEffectRecord := preload("eq_effect_record.gd")
const EQError := preload("eq_error.gd")
const EQValidation := preload("eq_validation.gd")

const RESULT_VERSION := 1
const STATUS_SUCCESS := &"SUCCESS"
const STATUS_FAILURE := &"FAILURE"

var _status: StringName = STATUS_FAILURE
var _records: Array = []
var _event_views: Array = []
var _diagnostic: Dictionary = {}


static func make_success(records: Array, event_views: Array):
	var result = _new_result()
	result._status = STATUS_SUCCESS
	result._records = records.duplicate()
	result._event_views = event_views.duplicate(true)
	return result


static func make_failure(diagnostic: Dictionary):
	var result = _new_result()
	result._status = STATUS_FAILURE
	result._diagnostic = diagnostic.duplicate(true)
	return result


## Avoid a same-file class_name lookup here. A newly linked addon script may be
## parsed before Godot has populated the consuming project's global class cache.
static func _new_result():
	var script = load("res://addons/event_queue_manager/runtime/eq_effect_commit_result.gd")
	return script.new()


func version() -> int:
	return RESULT_VERSION


func is_success() -> bool:
	return _status == STATUS_SUCCESS


func is_failure() -> bool:
	return _status == STATUS_FAILURE


## A shallow copy of the record list. EQEffectRecord is the existing mutable
## core DTO; the latest-outcome inspection surface below serializes it to an
## isolated Dictionary instead of leaking these references.
func records() -> Array:
	return _records.duplicate()


func event_views() -> Array:
	return _event_views.duplicate(true)


func diagnostic() -> Dictionary:
	return _diagnostic.duplicate(true)


func validate() -> EQValidation:
	var out := EQValidation.new()
	if _status != STATUS_SUCCESS and _status != STATUS_FAILURE:
		out.add(
			EQError.EFFECT_COMMIT_RESULT_INVALID,
			"effect commit result status must be SUCCESS or FAILURE"
		)
		return out
	if _status == STATUS_SUCCESS:
		for record in _records:
			if not (record is EQEffectRecord):
				out.add(
					EQError.EFFECT_COMMIT_RESULT_INVALID,
					"SUCCESS records must contain only EQEffectRecord values"
				)
				break
		for view in _event_views:
			if typeof(view) != TYPE_DICTIONARY or not _is_serializable(view):
				out.add(
					EQError.EFFECT_COMMIT_RESULT_INVALID,
					"SUCCESS event_views must contain only serializable Dictionaries"
				)
				break
		if not _diagnostic.is_empty():
			out.add(EQError.EFFECT_COMMIT_RESULT_INVALID, "SUCCESS must not carry a diagnostic")
	else:
		if not _records.is_empty() or not _event_views.is_empty():
			out.add(
				EQError.EFFECT_COMMIT_RESULT_INVALID,
				"FAILURE must not carry records or event_views"
			)
		if not _is_serializable(_diagnostic):
			out.add(EQError.EFFECT_COMMIT_RESULT_INVALID, "FAILURE diagnostic must be serializable")
	return out


## Canonical read-only projection used by EQReservationRuntime's latest-outcome
## accessor. SUCCESS records are value dictionaries, not live record objects.
func to_dict() -> Dictionary:
	if is_success():
		var record_dicts: Array = []
		for record in _records:
			if record is EQEffectRecord:
				record_dicts.append((record as EQEffectRecord).to_dict())
		return {
			"effect_commit_result_version": RESULT_VERSION,
			"status": String(STATUS_SUCCESS),
			"records": record_dicts,
			"event_views": _event_views.duplicate(true),
		}
	return {
		"effect_commit_result_version": RESULT_VERSION,
		"status": String(STATUS_FAILURE),
		"diagnostic": _diagnostic.duplicate(true),
	}


static func _is_serializable(value) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for item in value as Array:
				if not _is_serializable(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in (value as Dictionary).keys():
				if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
					return false
				if not _is_serializable((value as Dictionary)[key]):
					return false
			return true
		_:
			return false
