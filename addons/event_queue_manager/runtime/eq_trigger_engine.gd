class_name EQTriggerEngine
extends RefCounted
## L2 reaction-preparation runtime: holds armed reactions and fires them at the
## sweep point (the collection window after each event resolves,
## EVENT_MODEL_SEMANTICS §6 — never interleaved mid-resolution).
##
## A reaction is an armed REACTION_PREPARATION reservation paired with an
## EQCondition. When a matching event resolves, the reaction fires (a
## counterattack). Duration expiry removes it before it can fire (the reaction
## window closed). Owner/source are distinguished through the condition
## (e.g. match_target = owner, or a custom predicate rejecting source == owner),
## so a counter reacts to an enemy's incoming damage, not the owner's own.
##
## Firing is one-shot here; rumination (re-arming N times) and the infinite-chain
## cycle guard are EQM-062.

const EQReservation := preload("eq_reservation.gd")
const EQActionDefinition := preload("../resources/eq_action_definition.gd")

# Each armed entry: { reservation, condition, owner, armed_at, duration }.
var _armed: Array[Dictionary] = []


## Arms a reaction (a REACTION_PREPARATION reservation) with the condition that
## selects which incoming events trigger it. `current_tick` starts its lifetime.
func arm(reservation: EQReservation, condition, current_tick: int) -> void:
	reservation.status = EQReservation.Status.ARMED
	_armed.append({
		"reservation": reservation,
		"condition": condition,
		"owner": reservation.actor_id,
		"armed_at": current_tick,
		"duration": reservation.definition.duration if reservation.definition != null else EQActionDefinition.DURATION_UNLIMITED,
	})


## Sweep point: call right after an event resolves. First expires timed-out
## reactions (so an expired reaction cannot fire), then fires every armed
## reaction whose condition matches the event view. Fired/expired reactions are
## removed (one-shot). Returns the fired reservations (in arm order).
func on_event_resolved(view: Dictionary, current_tick: int) -> Array:
	_expire(current_tick)
	var fired: Array = []
	var survivors: Array[Dictionary] = []
	for armed in _armed:
		var cond = armed["condition"]
		if cond != null and cond.matches(view):
			var res: EQReservation = armed["reservation"]
			res.status = EQReservation.Status.RESOLVED
			fired.append(res)
		else:
			survivors.append(armed)
	_armed = survivors
	return fired


## Drops armed reactions whose duration has elapsed (duration -1 = unlimited
## never expires). Expiry is evaluated before firing.
func _expire(current_tick: int) -> void:
	var survivors: Array[Dictionary] = []
	for armed in _armed:
		var dur: int = int(armed["duration"])
		if dur == EQActionDefinition.DURATION_UNLIMITED or (current_tick - int(armed["armed_at"])) <= dur:
			survivors.append(armed)
		else:
			(armed["reservation"] as EQReservation).status = EQReservation.Status.INVALIDATED
	_armed = survivors


func armed_count() -> int:
	return _armed.size()


## Armed reactions owned by an actor (for inspection).
func armed_for(actor_id: StringName) -> Array:
	return _armed.filter(func(a): return a["owner"] == actor_id)
