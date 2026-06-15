class_name EQReservation
extends RefCounted
## L2 runtime instance of a reservation: an actor's pending action with its
## definition and mutable counters/status. The scheduling/resolution pipeline
## that drives these is EQM-051.
##
## Serializable: to_dict inlines the definition by value and never stores a live
## Node reference (Adapter rule), so a snapshot survives save/load.

const EQActionDefinition := preload("../resources/eq_action_definition.gd")

enum Status { PENDING, ARMED, RESOLVED, INVALIDATED }

var actor_id: StringName = &""
var definition: EQActionDefinition
## Scheduler event id once scheduled (-1 = not yet scheduled).
var event_id: int = -1
var status: int = Status.PENDING
## Countdowns initialised from the definition; consumed by the pipeline (EQM-051/062).
var remaining_ruminations: int = 0
var remaining_duration: int = 0


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
	return v


func to_dict() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"definition": definition.to_dict() if definition != null else {},
		"event_id": event_id,
		"status": status,
		"remaining_ruminations": remaining_ruminations,
		"remaining_duration": remaining_duration,
	}


static func from_dict(d: Dictionary) -> EQReservation:
	var def: EQActionDefinition = null
	var dd = d.get("definition", {})
	if dd is Dictionary and not (dd as Dictionary).is_empty():
		def = EQActionDefinition.from_dict(dd)
	var r := EQReservation.new(StringName(d.get("actor_id", "")), def)
	r.event_id = int(d.get("event_id", -1))
	r.status = int(d.get("status", Status.PENDING))
	r.remaining_ruminations = int(d.get("remaining_ruminations", r.remaining_ruminations))
	r.remaining_duration = int(d.get("remaining_duration", r.remaining_duration))
	return r
