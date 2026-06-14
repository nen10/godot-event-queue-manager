class_name EQActorState
extends RefCounted
## Engine-side state for one actor.
##
## Identity is the serializable `actor_id`. Progression/attributes the game cares
## about (WT/CT/AP/initiative/...) live in the acceptance-defined `data`
## Dictionary, NOT as built-in fields — per-entity progression is acceptance-
## defined (EVENT_MODEL_SEMANTICS §4.1, Q16), so the engine does not fix one
## meaning here. The link to the live game object is a transient WeakRef that is
## never serialized (the Adapter rule: bridge with actor_id/WeakRef, never store
## a live Node in the save form). Real rebind-on-load is EQM-085.

var actor_id: StringName = &""
var data: Dictionary = {}

var _binding: WeakRef = null


func _init(p_actor_id: StringName = &"") -> void:
	actor_id = p_actor_id


## Weakly binds the live game object (placeholder for the EQM-085 node bridge).
func bind(obj: Object) -> void:
	_binding = weakref(obj) if obj != null else null


## The bound object, or null if never bound or already freed (→ EXTERNAL_STATE).
func bound() -> Object:
	return _binding.get_ref() if _binding != null else null


func is_bound() -> bool:
	return bound() != null


## Serializable form: identity + acceptance data only. The weak binding is
## deliberately absent — live references never enter the save form.
func to_dict() -> Dictionary:
	return {"actor_id": String(actor_id), "data": data.duplicate(true)}


static func from_dict(d: Dictionary) -> EQActorState:
	var s := EQActorState.new(StringName(d.get("actor_id", "")))
	s.data = (d.get("data", {}) as Dictionary).duplicate(true)
	return s
