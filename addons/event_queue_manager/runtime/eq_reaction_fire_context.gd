class_name EQReactionFireContext
extends RefCounted
## Versioned, game-vocabulary-neutral value carried by one scheduled reaction
## FIRE occurrence. The trigger event view is consumer-owned data; EQM only
## captures, validates, copies, persists, and replays it.

const EQError := preload("eq_error.gd")
const EQValidation := preload("eq_validation.gd")

const VERSION := 1
const VERSION_FIELD := "reaction_fire_context_version"


## Builds an isolated JSON-safe context. Returns {} when the supplied value is
## outside the contract; callers surface the stable validation code.
static func capture(
	fire_event_id: int,
	trigger_event_id: int,
	trigger_view_index: int,
	trigger_tick: int,
	fire_index: int,
	event_view: Dictionary
) -> Dictionary:
	var canonical_view = canonical_event_view(event_view)
	if canonical_view.is_empty() and not event_view.is_empty():
		return {}
	var context := {
		VERSION_FIELD: VERSION,
		"fire_event_id": fire_event_id,
		"fire_index": fire_index,
		"trigger": {
			"event_id": trigger_event_id,
			"view_index": trigger_view_index,
			"tick": trigger_tick,
			"source": String(canonical_view.get("source", "")),
			"target": String(canonical_view.get("target", "")),
			"cell": canonical_view.get("cell", null),
		},
		"event_view": canonical_view,
	}
	return context if validate(context).is_valid() else {}


static func validate(value) -> EQValidation:
	var out := EQValidation.new()
	if typeof(value) != TYPE_DICTIONARY:
		out.add(EQError.REACTION_FIRE_CONTEXT_INVALID, "reaction fire context must be a Dictionary")
		return out
	var context: Dictionary = value
	var expected_fields := [
		VERSION_FIELD, "fire_event_id", "fire_index", "trigger", "event_view"
	]
	for field in expected_fields:
		if not context.has(field):
			out.add(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"reaction fire context is missing '%s'" % field,
				{"field": field, "reason": "missing_field"}
			)
			return out
	for field in context.keys():
		if not expected_fields.has(String(field)):
			out.add(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"reaction fire context has an unknown field '%s'" % String(field),
				{"field": String(field), "reason": "unknown_field"}
			)
			return out
	if typeof(context[VERSION_FIELD]) != TYPE_INT or int(context[VERSION_FIELD]) != VERSION:
		out.add(
			EQError.REACTION_FIRE_CONTEXT_INVALID,
			"reaction fire context version is unsupported",
			{"actual": context[VERSION_FIELD], "supported": VERSION}
		)
		return out
	if typeof(context["fire_event_id"]) != TYPE_INT or int(context["fire_event_id"]) < 1:
		out.add(EQError.REACTION_FIRE_CONTEXT_INVALID, "fire_event_id must be a positive int")
		return out
	if typeof(context["fire_index"]) != TYPE_INT or int(context["fire_index"]) < 1:
		out.add(EQError.REACTION_FIRE_CONTEXT_INVALID, "fire_index must be a positive int")
		return out
	if typeof(context["trigger"]) != TYPE_DICTIONARY:
		out.add(EQError.REACTION_FIRE_CONTEXT_INVALID, "trigger must be a Dictionary")
		return out
	var trigger: Dictionary = context["trigger"]
	var expected_trigger_fields := ["event_id", "view_index", "tick", "source", "target", "cell"]
	for field in expected_trigger_fields:
		if not trigger.has(field):
			out.add(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"reaction trigger is missing '%s'" % field,
				{"field": field, "reason": "missing_field"}
			)
			return out
	for field in trigger.keys():
		if not expected_trigger_fields.has(String(field)):
			out.add(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"reaction trigger has an unknown field '%s'" % String(field),
				{"field": String(field), "reason": "unknown_field"}
			)
			return out
	for field in ["event_id", "view_index", "tick"]:
		if typeof(trigger[field]) != TYPE_INT or int(trigger[field]) < 0:
			out.add(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"trigger.%s must be a non-negative int" % field,
				{"field": field}
			)
			return out
	for field in ["source", "target"]:
		if typeof(trigger[field]) != TYPE_STRING and typeof(trigger[field]) != TYPE_STRING_NAME:
			out.add(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"trigger.%s must be a String" % field,
				{"field": field}
			)
			return out
	if typeof(context["event_view"]) != TYPE_DICTIONARY:
		out.add(EQError.REACTION_FIRE_CONTEXT_INVALID, "event_view must be a Dictionary")
		return out
	if not _is_json_safe(context):
		out.add(
			EQError.REACTION_FIRE_CONTEXT_INVALID,
			"reaction fire context must contain only JSON-safe deterministic values",
			{"reason": "non_serializable_value"}
		)
	return out


static func copy(value: Dictionary) -> Dictionary:
	return value.duplicate(true) if validate(value).is_valid() else {}


## Canonical deep value-copy used before condition matching. StringName is
## normalized to String so save JSON and trace JSON carry the same value shape.
static func canonical_event_view(value: Dictionary) -> Dictionary:
	if not _is_json_safe(value):
		return {}
	return _canonical_copy(value)


static func _canonical_copy(value):
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var array: Array = []
			for item in value as Array:
				array.append(_canonical_copy(item))
			return array
		TYPE_DICTIONARY:
			var dictionary := {}
			for key in (value as Dictionary).keys():
				dictionary[String(key)] = _canonical_copy((value as Dictionary)[key])
			return dictionary
		_:
			return value


static func _is_json_safe(value) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for item in value as Array:
				if not _is_json_safe(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in (value as Dictionary).keys():
				if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
					return false
				if not _is_json_safe((value as Dictionary)[key]):
					return false
			return true
		_:
			return false
