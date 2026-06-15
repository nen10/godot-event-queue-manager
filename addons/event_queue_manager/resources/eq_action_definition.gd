class_name EQActionDefinition
extends Resource
## L2 reservation schema (Action Resolution Turn-Based). Authored Resource that
## declares the shape of a reservation; the runtime instance is EQReservation.
##
## This is opt-in deep-path surface — L0/L1 turn-order users never touch it
## (roadmap §3.1). The scheduling/resolution pipeline is EQM-051; conditions are
## EQM-060; rumination's cycle guard is EQM-062 (here `rumination` is just the
## declared re-arm count).

## Reservation kinds (EVENT_MODEL_SEMANTICS §5–§7; the user's Action Resolution model).
enum Kind {
	IMMEDIATE,             ## resolves now (delay 0)
	PREPARED,              ## resolves after a delay (preparation)
	REACTION_PREPARATION,  ## armed for `duration`, triggers on a matching event
	WAIT,                  ## ends the turn; schedules a READY reservation
	READY,                 ## the turn-grant after AP recovery (EQM-052)
	OPERATION,             ## causes a reservation on the target
}

## Sentinel for `duration`: armed with no tick deadline (closes only by reaction
## count, Q06).
const DURATION_UNLIMITED := -1

@export var kind: Kind = Kind.IMMEDIATE
## Resolution delay in event-line ticks (>= 0).
@export var delay: int = 0
## Free-form action tags for condition/trigger matching (EQM-060).
@export var tags: Array[StringName] = []
## Armed lifetime for REACTION_PREPARATION; DURATION_UNLIMITED (-1) = ∞.
@export var duration: int = 0
## Re-arm / re-schedule count for rumination (>= 0; cycle guard is EQM-062).
@export var rumination: int = 0
## For OPERATION: the tag of the reservation caused on the target.
@export var operation_target_tag: StringName = &""


func validate() -> EQValidation:
	var v := EQValidation.new()
	if delay < 0:
		v.add(EQError.RESERVATION_NEGATIVE_DELAY, "delay must be >= 0 (got %d)" % delay)
	if rumination < 0:
		v.add(EQError.RESERVATION_NEGATIVE_RUMINATION, "rumination must be >= 0 (got %d)" % rumination)
	if duration < DURATION_UNLIMITED:
		v.add(EQError.RESERVATION_INVALID_DURATION, "duration must be >= -1 (-1 = unlimited) (got %d)" % duration)
	match kind:
		Kind.IMMEDIATE:
			if delay != 0:
				v.add(EQError.RESERVATION_IMMEDIATE_NONZERO_DELAY, "IMMEDIATE requires delay 0 (got %d)" % delay)
		Kind.PREPARED:
			if delay <= 0:
				v.add(EQError.RESERVATION_PREPARED_ZERO_DELAY, "PREPARED requires delay > 0 (got %d)" % delay)
		Kind.REACTION_PREPARATION:
			if duration == 0:
				v.add(EQError.RESERVATION_REACTION_NEEDS_DURATION, "REACTION_PREPARATION requires a duration (> 0, or -1 for unlimited)")
		Kind.OPERATION:
			if operation_target_tag == &"":
				v.add(EQError.RESERVATION_OPERATION_NEEDS_TARGET, "OPERATION requires operation_target_tag")
		_:
			pass
	return v


func to_dict() -> Dictionary:
	return {
		"kind": int(kind),
		"delay": delay,
		"tags": tags.map(func(t): return String(t)),
		"duration": duration,
		"rumination": rumination,
		"operation_target_tag": String(operation_target_tag),
	}


static func from_dict(d: Dictionary) -> EQActionDefinition:
	var def := EQActionDefinition.new()
	def.kind = int(d.get("kind", Kind.IMMEDIATE)) as Kind
	def.delay = int(d.get("delay", 0))
	var t: Array[StringName] = []
	for s in d.get("tags", []):
		t.append(StringName(s))
	def.tags = t
	def.duration = int(d.get("duration", 0))
	def.rumination = int(d.get("rumination", 0))
	def.operation_target_tag = StringName(d.get("operation_target_tag", ""))
	return def
