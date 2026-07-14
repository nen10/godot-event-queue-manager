class_name EQReservation
extends RefCounted
## L2 runtime instance of a reservation: an actor's pending action with its
## definition and mutable counters/status. The scheduling/resolution pipeline
## that drives these is EQM-051.
##
## Serializable: to_dict inlines the definition by value and never stores a live
## Node reference (Adapter rule), so a snapshot survives save/load.

enum Status { PENDING, ARMED, RESOLVED, INVALIDATED }

const EQActionDefinition := preload("../resources/eq_action_definition.gd")

var actor_id: StringName = &""
var definition: EQActionDefinition
## For OPERATION reservations: the actor the caused reservation lands on.
var target_id: StringName = &""
## Provenance chain for target-causal expansion and transforms.
var provenance: Array = []
## Scheduler event id once scheduled (-1 = not yet scheduled).
var event_id: int = -1
var status: int = Status.PENDING
## Countdowns initialised from the definition; consumed by the pipeline (EQM-051/062).
var remaining_ruminations: int = 0
var remaining_duration: int = 0
## Named-effect registry contract versions captured on the first submit.
## -1 = not submitted yet; 0 = legacy Array handler; 1 = typed commit result.
## These are instance facts (not definition authoring fields) and cross saves so
## a registry mode swap can never reinterpret an already-issued reservation.
var effect_commit_result_version: int = -1
var expiry_effect_commit_result_version: int = -1


func _init(p_actor_id: StringName = &"", p_definition: EQActionDefinition = null) -> void:
	actor_id = p_actor_id
	definition = p_definition
	if definition != null:
		remaining_ruminations = definition.rumination
		remaining_duration = definition.duration


func validate() -> EQValidation:
	var v := EQValidation.new()
	if definition == null:
		v.add(EQError.RESERVATION_MISSING_DEFINITION, "reservation has no definition")
		return v
	# delegate the schema checks, then add any instance-level ones
	for issue in definition.validate().issues:
		v.issues.append(issue)
	for binding in [
		["effect_commit_result_version", effect_commit_result_version],
		["expiry_effect_commit_result_version", expiry_effect_commit_result_version],
	]:
		var version := int(binding[1])
		if version < -1 or version > 1:
			v.add(
				EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED,
				"%s must be -1 (unbound), 0 (legacy), or 1 (typed)" % binding[0],
				{"field": binding[0], "version": version}
			)
	return v


func to_dict() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"target_id": String(target_id),
		"definition": definition.to_dict() if definition != null else {},
		"event_id": event_id,
		"status": status,
		"remaining_ruminations": remaining_ruminations,
		"remaining_duration": remaining_duration,
		"effect_commit_result_version": effect_commit_result_version,
		"expiry_effect_commit_result_version": expiry_effect_commit_result_version,
		"provenance": provenance.duplicate(true),
	}


static func from_dict(d: Dictionary) -> EQReservation:
	var def: EQActionDefinition = null
	var dd = d.get("definition", {})
	if dd is Dictionary and not (dd as Dictionary).is_empty():
		def = EQActionDefinition.from_dict(dd)
	var r := EQReservation.new(StringName(d.get("actor_id", "")), def)
	r.target_id = StringName(d.get("target_id", ""))
	r.event_id = int(d.get("event_id", -1))
	r.status = int(d.get("status", Status.PENDING))
	r.remaining_ruminations = int(d.get("remaining_ruminations", r.remaining_ruminations))
	r.remaining_duration = int(d.get("remaining_duration", r.remaining_duration))
	# Historical saves predate typed results and therefore bind to legacy (0),
	# not to the fresh-instance sentinel (-1).
	r.effect_commit_result_version = int(d.get("effect_commit_result_version", 0))
	r.expiry_effect_commit_result_version = int(d.get("expiry_effect_commit_result_version", 0))
	var provenance = d.get("provenance", [])
	if provenance is Array:
		r.provenance = provenance.duplicate(true)
	return r
