class_name EQPresentationEvent
extends RefCounted
## A presentation-side visual request, queued separately from the simulation
## (the simulation/presentation split, Phase 8). Deferred / coalesced / skipped
## by the flush policy (EQM-081) without ever touching the simulation.
##
## It carries `actor_id` and a `position` *value snapshot captured at queue time*
## (not a live lookup), so the moving-target barrier (EQM-082) can compare the
## position a visual assumes against one a pending visual changes. The live node,
## if any, is a transient WeakRef and is never serialized (Adapter rule).
## `classification` is the consumer-supplied sensing class read by the flush policy.

const EQEffectRecord := preload("eq_effect_record.gd")

var actor_id: StringName = &""
## Value snapshot (e.g. Vector2/Vector3/any serializable) of the position this
## visual assumes, captured when queued.
var position: Variant = null
var classification: StringName = &""
var tags: Array[StringName] = []
## Entities whose displayed position this visual changes (barrier producers).
var changes_position_of: Array[StringName] = []
## Entities whose displayed position this visual assumes (barrier consumers).
var depends_on: Array[StringName] = []

var _binding: WeakRef = null


func _init(p_actor_id: StringName = &"", p_position: Variant = null, p_classification: StringName = &"") -> void:
	actor_id = p_actor_id
	position = p_position
	classification = p_classification


## Transient link to the live render node (never serialized).
func bind(obj: Object) -> void:
	_binding = weakref(obj) if obj != null else null


func bound() -> Object:
	return _binding.get_ref() if _binding != null else null


## Serializable form: no live reference; position is a value.
func to_dict() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"position": position,
		"classification": String(classification),
		"tags": tags.map(func(x): return String(x)),
		"changes_position_of": changes_position_of.map(func(x): return String(x)),
		"depends_on": depends_on.map(func(x): return String(x)),
	}


static func from_dict(d: Dictionary) -> EQPresentationEvent:
	var e := EQPresentationEvent.new(StringName(d.get("actor_id", "")), d.get("position", null), StringName(d.get("classification", "")))
	e.tags = _to_names(d.get("tags", []))
	e.changes_position_of = _to_names(d.get("changes_position_of", []))
	e.depends_on = _to_names(d.get("depends_on", []))
	return e


static func _to_names(arr) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in arr:
		out.append(StringName(s))
	return out
