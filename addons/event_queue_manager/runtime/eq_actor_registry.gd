class_name EQActorRegistry
extends RefCounted
## Single owner of actor_id registration.
##
## actor_id is unique and never reused (EVENT_MODEL_SEMANTICS §13 / Q10): an id
## that is currently registered is a duplicate, and an id that was registered
## and later removed is retired and may not be re-registered. This is what backs
## the totality of EQConfig's `tie_break = &"actor_id"` (EQM-020). Registration
## rejects with null (no silent overwrite); validate_register reports the code.

var _active: Dictionary = {}    # actor_id -> EQActorState
var _retired: Dictionary = {}   # actor_id -> true (never reusable)


## Reports whether an id may be registered now (empty / duplicate / reused).
func validate_register(actor_id: StringName) -> EQValidation:
	var v := EQValidation.new()
	if actor_id == &"":
		v.add(EQError.ACTOR_EMPTY_ID, "actor_id is empty")
	elif _active.has(actor_id):
		v.add(EQError.ACTOR_DUPLICATE_ID, "actor_id already registered: %s" % String(actor_id))
	elif _retired.has(actor_id):
		v.add(EQError.ACTOR_ID_REUSED, "actor_id was used before and cannot be reused: %s" % String(actor_id))
	return v


## Registers a new actor, returning its EQActorState, or null on rejection
## (empty / duplicate / reused). State is unchanged on rejection.
func register(actor_id: StringName) -> EQActorState:
	if not validate_register(actor_id).is_valid():
		return null
	var s := EQActorState.new(actor_id)
	_active[actor_id] = s
	return s


func is_registered(actor_id: StringName) -> bool:
	return _active.has(actor_id)


func get_state(actor_id: StringName) -> EQActorState:
	return _active.get(actor_id, null)


## Removes an actor. The id becomes retired and can never be reused. Returns
## true if it was active.
func unregister(actor_id: StringName) -> bool:
	if not _active.has(actor_id):
		return false
	_active.erase(actor_id)
	_retired[actor_id] = true
	return true


func actor_ids() -> Array:
	return _active.keys()


func size() -> int:
	return _active.size()
