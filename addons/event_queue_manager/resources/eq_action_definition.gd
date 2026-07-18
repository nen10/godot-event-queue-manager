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
## Declarative level for provenance reachability and transformation matching.
@export var meta_level: int = 0
## Declarative state annotation attached to the event view.
@export var state_name: StringName = &""
## Ordering priority of the scheduled resolution event (higher first at the
## same tick, §3). Q32: a fired reaction is scheduled with this value.
@export var priority: int = 0
## Named effect applied at resolution (SEM §6.1, declared linkage): empty =
## explicitly effect-less; set-but-unregistered is a stable error, never a
## silent skip. Register via EQRuntime.register_effect.
@export var effect_name: StringName = &""
## Optional named effect applied when a duration expiry closes this reservation
## (SEM §6.3). Same registry and error rule as effect_name.
@export var expiry_effect_name: StringName = &""
## Solve terms — AND, level-triggered (SEM §5.4, EQM-111). Empty = no gate.
## COUNTER is rejected here because it progresses only after accepted resolve.
@export var solve_conditions: Array[EQConditionSpec] = []
## Invalidation terms — OR, invalidation-wins (SEM §5.4); COUNTER belongs here.
## `duration` and
## `rumination` above are sugar over these; see normalized_conditions().
@export var invalidation_conditions: Array[EQConditionSpec] = []

## The primary event-line (global tick) id, referenced by the duration sugar.
## The event-line backend (EQM-112) adopts this constant as the canonical id.
const PRIMARY_LINE_ID := &"eqm.line.primary"


func validate() -> EQValidation:
	var v := EQValidation.new()
	if delay < 0:
		v.add(EQError.RESERVATION_NEGATIVE_DELAY, "delay must be >= 0 (got %d)" % delay)
	if rumination < 0:
		v.add(EQError.RESERVATION_NEGATIVE_RUMINATION, "rumination must be >= 0 (got %d)" % rumination)
	if duration < DURATION_UNLIMITED:
		v.add(EQError.RESERVATION_INVALID_DURATION, "duration must be >= -1 (-1 = unlimited) (got %d)" % duration)
	for i in range(solve_conditions.size()):
		if solve_conditions[i] != null:
			for issue in solve_conditions[i].validate().issues:
				v.issues.append(issue)
			if solve_conditions[i].type == EQConditionSpec.Type.COUNTER:
				v.add(
					EQError.CONDITION_COUNTER_SOLVE_UNSUPPORTED,
					"COUNTER is an invalidation-only condition; solve COUNTER cannot self-progress",
					{"index": i}
				)
	for i in range(invalidation_conditions.size()):
		if invalidation_conditions[i] != null:
			for issue in invalidation_conditions[i].validate().issues:
				v.issues.append(issue)
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


## The full condition sets with the sugar fields folded in (SEM §5.6):
## `duration` > 0 becomes a relative LINE_THRESHOLD on the primary line
## (condition_id "duration"; the pipeline realizes it as an expiry event, §6.3);
## `rumination` > 0 becomes a COUNTER allowing rumination+1 resolutions
## (condition_id "reaction_count"). Declared conditions keep their order and
## precede the sugar terms. Returns {"solve": [...], "invalidation": [...]}.
func normalized_conditions() -> Dictionary:
	var solve: Array[EQConditionSpec] = []
	for s in solve_conditions:
		if s != null:
			solve.append(s)
	var invalidation: Array[EQConditionSpec] = []
	for s in invalidation_conditions:
		if s != null:
			invalidation.append(s)
	if duration > 0:
		var dur := EQConditionSpec.new()
		dur.type = EQConditionSpec.Type.LINE_THRESHOLD
		dur.line_id = PRIMARY_LINE_ID
		dur.threshold = duration
		dur.comparison = EQConditionSpec.Comparison.GE
		dur.relative = true
		dur.condition_id = &"duration"
		invalidation.append(dur)
	if rumination > 0:
		var uses := EQConditionSpec.new()
		uses.type = EQConditionSpec.Type.COUNTER
		uses.counter_start = rumination + 1
		uses.condition_id = &"reaction_count"
		invalidation.append(uses)
	return {"solve": solve, "invalidation": invalidation}


func to_dict() -> Dictionary:
	return {
		"kind": int(kind),
		"delay": delay,
		"tags": tags.map(func(t): return String(t)),
		"duration": duration,
		"rumination": rumination,
		"operation_target_tag": String(operation_target_tag),
		"meta_level": meta_level,
		"state_name": String(state_name),
		"priority": priority,
		"effect_name": String(effect_name),
		"expiry_effect_name": String(expiry_effect_name),
		"solve_conditions": solve_conditions.filter(func(s): return s != null).map(func(s): return s.to_dict()),
		"invalidation_conditions": invalidation_conditions.filter(func(s): return s != null).map(func(s): return s.to_dict()),
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
	def.meta_level = int(d.get("meta_level", 0))
	def.state_name = StringName(d.get("state_name", ""))
	def.priority = int(d.get("priority", 0))
	def.effect_name = StringName(d.get("effect_name", ""))
	def.expiry_effect_name = StringName(d.get("expiry_effect_name", ""))
	var solve: Array[EQConditionSpec] = []
	for sd in d.get("solve_conditions", []):
		solve.append(EQConditionSpec.from_dict(sd))
	def.solve_conditions = solve
	var invalidation: Array[EQConditionSpec] = []
	for sd in d.get("invalidation_conditions", []):
		invalidation.append(EQConditionSpec.from_dict(sd))
	def.invalidation_conditions = invalidation
	return def
