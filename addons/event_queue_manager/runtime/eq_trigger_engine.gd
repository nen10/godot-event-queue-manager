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
## Firing is one-shot here; rumination (re-arming N times) is EQM-062. Fired
## reactions are SCHEDULED onto the master timeline by the resolution pipeline
## (EQReservationRuntime, SEM §6.2) — the in-place cascade (`fire_cascade`) was
## removed by EQM-113 (Q32): the pipeline's bounded same-tick rounds replaced it.

const EQReservation := preload("eq_reservation.gd")
const EQActionDefinition := preload("../resources/eq_action_definition.gd")

# Each armed entry: { reservation, condition, owner, armed_at, duration }.
var _armed: Array[Dictionary] = []

## Observable record of duration-expired reactions ({reservation, expired_at}) —
## expiry is never silent (Q06/SEM §6.3). Pipeline-owned reactions arm with
## DURATION_UNLIMITED here; their expiry is an expiry EVENT owned by EQM-113.
var expired: Array[Dictionary] = []


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
			fired.append(res)
			# rumination: re-arm while ruminations remain, else consume (one-shot).
			if res.remaining_ruminations > 0:
				res.remaining_ruminations -= 1
				res.status = EQReservation.Status.ARMED
				survivors.append(armed)
			else:
				res.status = EQReservation.Status.RESOLVED
		else:
			survivors.append(armed)
	_armed = survivors
	return fired


## Disarms one reservation (e.g. an expiry event closed it, or its owner left).
## Returns whether it was armed.
func disarm(reservation: EQReservation) -> bool:
	for i in range(_armed.size()):
		if _armed[i]["reservation"] == reservation:
			_armed.remove_at(i)
			return true
	return false


## Disarms every reaction owned by an actor (the Q39 departure path). Returns
## the disarmed reservations.
func disarm_for(actor_id: StringName) -> Array:
	var removed: Array = []
	var survivors: Array[Dictionary] = []
	for armed in _armed:
		if armed["owner"] == actor_id:
			removed.append(armed["reservation"])
		else:
			survivors.append(armed)
	_armed = survivors
	return removed


## Drops armed reactions whose duration has elapsed (duration -1 = unlimited
## never expires). Expiry is evaluated before firing and is OBSERVABLE via
## `expired` — never silent (standalone use; the pipeline uses expiry events).
func _expire(current_tick: int) -> void:
	var survivors: Array[Dictionary] = []
	for armed in _armed:
		var dur: int = int(armed["duration"])
		if dur == EQActionDefinition.DURATION_UNLIMITED or (current_tick - int(armed["armed_at"])) <= dur:
			survivors.append(armed)
		else:
			(armed["reservation"] as EQReservation).status = EQReservation.Status.INVALIDATED
			expired.append({"reservation": armed["reservation"], "expired_at": current_tick})
	_armed = survivors


func armed_count() -> int:
	return _armed.size()


## Read-only view of the armed entries ({reservation, condition, owner,
## armed_at, duration}) for serialization (EQM-117).
func armed_entries() -> Array:
	return _armed.duplicate()


## Armed reactions owned by an actor (for inspection).
func armed_for(actor_id: StringName) -> Array:
	return _armed.filter(func(a): return a["owner"] == actor_id)
