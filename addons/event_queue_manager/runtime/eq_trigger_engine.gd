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
const _EQTriggerIndex := preload("eq_trigger_index.gd")
const EQActionDefinition := preload("../resources/eq_action_definition.gd")
const _EQCondition := preload("../resources/eq_condition.gd")

# `_armed` is the sole canonical table. Private sequence/expiry keys support the
# non-serialized derived index and are never exposed by armed_entries().
# Each entry: { reservation, condition, owner, armed_at, duration,
#               _index_sequence, _commit_revision, _expiry_end_tick? }.
var _armed: Array[Dictionary] = []
var _index := _EQTriggerIndex.new()
var _armed_by_sequence: Dictionary = {}
# Minimum finite `armed_at + duration`; the boolean avoids overloading a valid
# (including invalid-input/negative-tick) end value as a sentinel.
# Expiry remains strict: an entry closes only when current_tick > this value.
var _has_finite_expiry: bool = false
var _next_expiry_end_tick: int = 0

## Observable record of duration-expired reactions ({reservation, expired_at}) —
## expiry is never silent (Q06/SEM §6.3). Pipeline-owned reactions arm with
## DURATION_UNLIMITED here; their expiry is an expiry EVENT owned by EQM-113.
var expired: Array[Dictionary] = []


## Arms a reaction (a REACTION_PREPARATION reservation) with the condition that
## selects which incoming events trigger it. `current_tick` starts its lifetime.
## Returns false without mutation unless condition is EQCondition or null.
func arm(reservation: EQReservation, condition, current_tick: int) -> bool:
	return _arm_slot(reservation, condition, current_tick) >= 0


## Runtime-internal slot form. The public bool arm() contract stays unchanged,
## while the reservation pipeline keys arm-bound state by this exact slot.
func _arm_slot(reservation: EQReservation, condition, current_tick: int) -> int:
	if condition != null and not is_instance_of(condition, _EQCondition):
		return -1
	var sequence := _index.add(reservation, condition)
	if sequence < 0:
		return -1
	var armed := {
		"reservation": reservation,
		"condition": condition,
		"owner": reservation.actor_id,
		"armed_at": current_tick,
		"duration": reservation.definition.duration if reservation.definition != null else EQActionDefinition.DURATION_UNLIMITED,
		"_index_sequence": sequence,
		"_commit_revision": 0,
	}
	_note_expiry(armed)
	_armed.append(armed)
	_armed_by_sequence[sequence] = armed
	reservation.status = EQReservation.Status.ARMED
	return sequence


## Non-mutating candidate phase for the sweep point. A result is an opaque
## preview token plus observable `{reservation, fire_index, closes_arm}` data.
## Call commit_occurrence() or invalidate_occurrence() exactly once. Expired
## slots are filtered without mutation; the compatibility sweep below performs
## the historical observable expiry mutation before it previews.
func preview_event_resolved_occurrences(view: Dictionary, current_tick: int) -> Array:
	var previews: Array = []
	for candidate in _index.candidates(view):
		var sequence := int(candidate["seq"])
		if not _armed_by_sequence.has(sequence):
			continue
		var armed: Dictionary = _armed_by_sequence[sequence]
		if _is_expired_at(armed, current_tick):
			continue
		var cond = armed["condition"]
		if cond != null and cond.matches(view):
			var res: EQReservation = armed["reservation"]
			var authored_ruminations := (
				res.definition.rumination if res.definition != null else 0
			)
			var closes_arm := res.remaining_ruminations <= 0
			previews.append(
				{
					"reservation": res,
					"fire_index": authored_ruminations - res.remaining_ruminations + 1,
					"closes_arm": closes_arm,
					"slot_id": sequence,
					"_arm_revision": int(armed["_commit_revision"]),
				}
			)
	return previews


## Commits one still-current preview. Stale or already-consumed tokens fail
## without mutation. Rumination changes only here, after the caller's gate.
func commit_occurrence(preview: Dictionary) -> bool:
	return _commit_occurrence_batch(
		[{"preview": preview, "count": 1, "close_status": -1}]
	)


## Closes one still-current preview without consuming rumination.
func invalidate_occurrence(preview: Dictionary) -> bool:
	return _commit_occurrence_batch(
		[
			{
				"preview": preview,
				"count": 0,
				"close_status": EQReservation.Status.INVALIDATED,
			}
		]
	)


## Compatibility sweep: previews and commits every matching candidate.
func on_event_resolved_occurrences(view: Dictionary, current_tick: int) -> Array:
	_expire(current_tick)
	var fired: Array = []
	for preview in preview_event_resolved_occurrences(view, current_tick):
		if commit_occurrence(preview):
			fired.append(preview)
	return fired


## Compatibility projection retained for direct trigger-engine consumers.
## The reservation lifecycle is identical; the pipeline uses the occurrence
## form above so it can bind an exact cause to each scheduled FIRE event.
func on_event_resolved(view: Dictionary, current_tick: int) -> Array:
	var reservations: Array = []
	for occurrence in on_event_resolved_occurrences(view, current_tick):
		reservations.append(occurrence["reservation"])
	return reservations


## Disarms one reservation (e.g. an expiry event closed it, or its owner left).
## Returns whether it was armed.
func disarm(reservation: EQReservation) -> bool:
	for i in range(_armed.size()):
		if _armed[i]["reservation"] == reservation:
			_unindex_slot(_armed[i])
			_armed.remove_at(i)
			return true
	return false


## Removes one exact arm slot. Runtime expiry/gate ownership uses this instead
## of reservation identity, because the direct engine explicitly permits the
## same reservation object to occupy more than one slot.
func _disarm_slot(slot_id: int) -> bool:
	if not _armed_by_sequence.has(slot_id):
		return false
	_remove_armed_entry(_armed_by_sequence[slot_id])
	return true


## Disarms every reaction owned by an actor (the Q39 departure path). Returns
## the disarmed reservations.
func disarm_for(actor_id: StringName) -> Array:
	var removed: Array = []
	for entry in _disarm_entries_for(actor_id):
		removed.append(entry["reservation"])
	return removed


func _disarm_entries_for(actor_id: StringName) -> Array:
	var removed: Array = []
	var survivors: Array[Dictionary] = []
	for armed in _armed:
		if armed["owner"] == actor_id:
			removed.append(_public_entry(armed))
			_unindex_slot(armed)
		else:
			survivors.append(armed)
	_armed = survivors
	return removed


## Drops armed reactions whose duration has elapsed (duration -1 = unlimited
## never expires). Expiry is evaluated before firing and is OBSERVABLE via
## `expired` — never silent (standalone use; the pipeline uses expiry events).
func _expire(current_tick: int) -> void:
	if not _has_finite_expiry or current_tick <= _next_expiry_end_tick:
		return
	var survivors: Array[Dictionary] = []
	var has_next_expiry := false
	var next_expiry := 0
	for armed in _armed:
		var dur: int = int(armed["duration"])
		if dur == EQActionDefinition.DURATION_UNLIMITED or (current_tick - int(armed["armed_at"])) <= dur:
			survivors.append(armed)
			if dur != EQActionDefinition.DURATION_UNLIMITED:
				var end_tick := int(armed["_expiry_end_tick"])
				if not has_next_expiry or end_tick < next_expiry:
					has_next_expiry = true
					next_expiry = end_tick
		else:
			(armed["reservation"] as EQReservation).status = EQReservation.Status.INVALIDATED
			expired.append({"reservation": armed["reservation"], "expired_at": current_tick})
			_unindex_slot(armed)
	_armed = survivors
	_has_finite_expiry = has_next_expiry
	_next_expiry_end_tick = next_expiry


func armed_count() -> int:
	return _armed.size()


## Read-only view of the armed entries ({reservation, condition, owner,
## armed_at, duration}) for serialization (EQM-117).
func armed_entries() -> Array:
	var entries: Array = []
	for armed in _armed:
		entries.append(_public_entry(armed))
	return entries


## Armed reactions owned by an actor (for inspection).
func armed_for(actor_id: StringName) -> Array:
	var entries: Array = []
	for armed in _armed:
		if armed["owner"] == actor_id:
			entries.append(_public_entry(armed))
	return entries


func _note_expiry(armed: Dictionary) -> void:
	var duration := int(armed["duration"])
	if duration == EQActionDefinition.DURATION_UNLIMITED:
		return
	var end_tick := int(armed["armed_at"]) + duration
	armed["_expiry_end_tick"] = end_tick
	if not _has_finite_expiry or end_tick < _next_expiry_end_tick:
		_has_finite_expiry = true
		_next_expiry_end_tick = end_tick


func _unindex_slot(armed: Dictionary) -> void:
	var sequence := int(armed["_index_sequence"])
	_index._remove_sequence(sequence)
	_armed_by_sequence.erase(sequence)


func _is_expired_at(armed: Dictionary, current_tick: int) -> bool:
	var duration := int(armed["duration"])
	return (
		duration != EQActionDefinition.DURATION_UNLIMITED
		and (current_tick - int(armed["armed_at"])) > duration
	)


func _live_preview_entry(preview: Dictionary) -> Dictionary:
	if not preview.has("slot_id") or not preview.has("_arm_revision"):
		return {}
	var sequence := int(preview["slot_id"])
	if not _armed_by_sequence.has(sequence):
		return {}
	var armed: Dictionary = _armed_by_sequence[sequence]
	if armed["reservation"] != preview.get("reservation", null):
		return {}
	if int(armed["_commit_revision"]) != int(preview["_arm_revision"]):
		return {}
	return armed


## Verifies a whole runtime FIRE plan without mutation. Each slot appears once;
## `count` is the number of accepted FIREs planned for it and close_status is
## -1, RESOLVED (declared counter), or INVALIDATED (gate/fault).
func _validate_occurrence_batch(plans: Array) -> bool:
	var seen_slots := {}
	var simulated_remaining := {}
	for plan_value in plans:
		if typeof(plan_value) != TYPE_DICTIONARY:
			return false
		var plan: Dictionary = plan_value
		var preview_value = plan.get("preview", {})
		if typeof(preview_value) != TYPE_DICTIONARY:
			return false
		var preview: Dictionary = preview_value
		var armed := _live_preview_entry(preview)
		if armed.is_empty():
			return false
		var slot_id := int(preview["slot_id"])
		if seen_slots.has(slot_id):
			return false
		seen_slots[slot_id] = true
		var count := int(plan.get("count", -1))
		var close_status := int(plan.get("close_status", -1))
		if count < 0 or not [-1, EQReservation.Status.RESOLVED, EQReservation.Status.INVALIDATED].has(close_status):
			return false
		if count == 0 and close_status == -1:
			return false
		var res: EQReservation = armed["reservation"]
		var reservation_id := res.get_instance_id()
		var remaining := int(
			simulated_remaining.get(reservation_id, res.remaining_ruminations)
		)
		if count > remaining + 1:
			return false
		if count > 0:
			remaining = maxi(remaining - count, 0)
		simulated_remaining[reservation_id] = remaining
	return true


func _commit_occurrence_batch(plans: Array) -> bool:
	if not _validate_occurrence_batch(plans):
		return false
	for plan_value in plans:
		var plan: Dictionary = plan_value
		var preview: Dictionary = plan["preview"]
		var armed: Dictionary = _armed_by_sequence[int(preview["slot_id"])]
		var res: EQReservation = armed["reservation"]
		var count := int(plan["count"])
		var close_status := int(plan["close_status"])
		armed["_commit_revision"] = int(armed["_commit_revision"]) + maxi(count, 1)
		if count > 0:
			if count <= res.remaining_ruminations:
				res.remaining_ruminations -= count
				res.status = EQReservation.Status.ARMED
			else:
				res.remaining_ruminations = 0
				res.status = EQReservation.Status.RESOLVED
				_remove_armed_entry(armed)
		if close_status != -1 and _armed_by_sequence.has(int(preview["slot_id"])):
			res.status = close_status
			_remove_armed_entry(armed)
	return true


func _remove_armed_entry(armed: Dictionary) -> void:
	_unindex_slot(armed)
	for i in range(_armed.size()):
		if _armed[i] == armed:
			_armed.remove_at(i)
			return


func _public_entry(armed: Dictionary) -> Dictionary:
	return {
		"reservation": armed["reservation"],
		"condition": armed["condition"],
		"owner": armed["owner"],
		"armed_at": armed["armed_at"],
		"duration": armed["duration"],
		"slot_id": int(armed["_index_sequence"]),
	}
