class_name EQConditionSpec
extends Resource
## L2 condition term for solve/invalidation condition sets (SEM §5.4/§5.6,
## EQM-111). Declares ONE term; an event/reservation carries arrays of these
## (`solve_conditions` = AND, `invalidation_conditions` = OR, invalidation-wins).
##
## Distinct from EQCondition (EQM-060), which matches a resolving event's view
## for trigger firing. EQConditionSpec gates when a pending event resolves or
## drops.
##
## Serializable only: NAMED_PREDICATE stores a registry name (EQRuntime
## `register_predicate`), never a Callable, so pending conditions survive
## save/load (SEM §5.5). Evaluation lives in EQConditionEval.

enum Type {
	LINE_THRESHOLD,   ## event-line value vs threshold (level semantics, Q34)
	COUNTER,          ## decremental counter sugar — binds to a counter line, holds at <= 0 (SEM §5.1)
	NAMED_PREDICATE,  ## registered predicate over a serializable view (SEM §5.5)
}

enum Comparison { GE, LE, EQ, GT, LT }

@export var type: Type = Type.LINE_THRESHOLD
## LINE_THRESHOLD: the event-line this term reads.
@export var line_id: StringName = &""
@export var threshold: int = 0
@export var comparison: Comparison = Comparison.GE
## LINE_THRESHOLD: when true, `threshold` is relative to the line's value at
## bind time (instantiation) and is fixed to an absolute value there ("N from
## now", the duration-sugar shape).
@export var relative: bool = false
## COUNTER: initial remaining count (>= 1); exhaustion (<= 0) makes the term hold.
@export var counter_start: int = 1
## NAMED_PREDICATE: name registered via EQRuntime.register_predicate.
@export var predicate_name: StringName = &""
## Optional stable id for trace `closed_by`; empty = deterministic
## "<group>:<index>" assigned at bind (SEM §5/§11).
@export var condition_id: StringName = &""


func validate() -> EQValidation:
	var v := EQValidation.new()
	match type:
		Type.LINE_THRESHOLD:
			if line_id == &"":
				v.add(EQError.CONDITION_LINE_ID_EMPTY, "LINE_THRESHOLD requires line_id")
		Type.COUNTER:
			if counter_start < 1:
				v.add(EQError.CONDITION_COUNTER_START_INVALID, "COUNTER requires counter_start >= 1 (got %d)" % counter_start)
		Type.NAMED_PREDICATE:
			if predicate_name == &"":
				v.add(EQError.CONDITION_PREDICATE_NAME_EMPTY, "NAMED_PREDICATE requires predicate_name")
	return v


func to_dict() -> Dictionary:
	return {
		"type": int(type),
		"line_id": String(line_id),
		"threshold": threshold,
		"comparison": int(comparison),
		"relative": relative,
		"counter_start": counter_start,
		"predicate_name": String(predicate_name),
		"condition_id": String(condition_id),
	}


static func from_dict(d: Dictionary) -> EQConditionSpec:
	var s := EQConditionSpec.new()
	s.type = int(d.get("type", Type.LINE_THRESHOLD)) as Type
	s.line_id = StringName(d.get("line_id", ""))
	s.threshold = int(d.get("threshold", 0))
	s.comparison = int(d.get("comparison", Comparison.GE)) as Comparison
	s.relative = bool(d.get("relative", false))
	s.counter_start = int(d.get("counter_start", 1))
	s.predicate_name = StringName(d.get("predicate_name", ""))
	s.condition_id = StringName(d.get("condition_id", ""))
	return s
