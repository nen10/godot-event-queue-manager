class_name EQConditionEval
extends RefCounted
## Pure evaluator for solve/invalidation condition sets (SEM §5.4, EQM-111).
##
## Semantics (all decided Q27–Q29, uniform, no opt-outs):
##   - level-triggered: a term reads the CURRENT ctx at the evaluation point;
##     nothing is latched between evaluations.
##   - solve = AND over all terms (empty set = vacuously true).
##   - invalidation = OR; the first term (in declared order) that holds names
##     the trace `closed_by`.
##   - decide() is invalidation-wins when both hold at the same point.
##
## The evaluator is pipeline-free and runtime-free: context is a plain dict
##   { "lines": {StringName: int}, "view": {…}, "predicates": {StringName: Callable} }
## so it is testable standalone; wiring into resolution is EQM-113. Faults are
## returned as values ({code, message, context}) — acting on them (dev halt vs
## shipped skip) is the resilience mode's job, never the evaluator's.

const EQConditionSpec := preload("../resources/eq_condition_spec.gd")

enum Result { NO, YES, FAULT }
enum Outcome { WAIT, RESOLVE, INVALIDATE, FAULT }


## Fixes a spec into an immutable term dict at instantiation time.
## - LINE_THRESHOLD with `relative` resolves to an absolute threshold using the
##   line's bind-time value (requires the line in ctx).
## - COUNTER binds to its runtime-assigned decremental counter line
##   (`counter_line_id`, required) as (counter_line, 0, LE) — SEM §5.1.
## - condition_id defaults to "<group>:<index>" (deterministic, for closed_by).
static func bind(spec: EQConditionSpec, group: String, index: int, ctx: Dictionary, counter_line_id: StringName = &"") -> Dictionary:
	var cid := spec.condition_id
	if cid == &"":
		cid = StringName("%s:%d" % [group, index])
	match spec.type:
		EQConditionSpec.Type.COUNTER:
			if counter_line_id == &"":
				return _fault_term(cid, EQError.CONDITION_LINE_ID_EMPTY, "COUNTER bind requires a counter_line_id")
			return {
				"type": EQConditionSpec.Type.LINE_THRESHOLD,
				"line_id": counter_line_id,
				"threshold": 0,
				"comparison": EQConditionSpec.Comparison.LE,
				"condition_id": cid,
			}
		EQConditionSpec.Type.LINE_THRESHOLD:
			var threshold := spec.threshold
			if spec.relative:
				var lines: Dictionary = ctx.get("lines", {})
				if not lines.has(spec.line_id):
					return _fault_term(cid, EQError.CONDITION_LINE_UNKNOWN, "relative bind: unknown line %s" % spec.line_id)
				threshold += int(lines[spec.line_id])
			return {
				"type": EQConditionSpec.Type.LINE_THRESHOLD,
				"line_id": spec.line_id,
				"threshold": threshold,
				"comparison": spec.comparison,
				"condition_id": cid,
			}
		_:
			return {
				"type": EQConditionSpec.Type.NAMED_PREDICATE,
				"predicate_name": spec.predicate_name,
				"condition_id": cid,
			}


static func _fault_term(cid: StringName, code: StringName, message: String) -> Dictionary:
	return {"type": -1, "condition_id": cid, "fault": {"code": code, "message": message}}


## Evaluates one bound term against the current ctx (level semantics).
## Returns {result: Result, fault: Dictionary|null}.
static func term_holds(term: Dictionary, ctx: Dictionary) -> Dictionary:
	if term.has("fault"):
		return {"result": Result.FAULT, "fault": term["fault"]}
	match int(term.get("type", -1)):
		EQConditionSpec.Type.LINE_THRESHOLD:
			var lines: Dictionary = ctx.get("lines", {})
			var line_id: StringName = term["line_id"]
			if not lines.has(line_id):
				return {"result": Result.FAULT, "fault": {
					"code": EQError.CONDITION_LINE_UNKNOWN,
					"message": "condition reads unknown line %s" % line_id,
					"context": {"condition_id": String(term["condition_id"])},
				}}
			var value := int(lines[line_id])
			var threshold := int(term["threshold"])
			var holds := false
			match int(term["comparison"]):
				EQConditionSpec.Comparison.GE: holds = value >= threshold
				EQConditionSpec.Comparison.LE: holds = value <= threshold
				EQConditionSpec.Comparison.EQ: holds = value == threshold
				EQConditionSpec.Comparison.GT: holds = value > threshold
				EQConditionSpec.Comparison.LT: holds = value < threshold
			return {"result": Result.YES if holds else Result.NO, "fault": null}
		EQConditionSpec.Type.NAMED_PREDICATE:
			var predicates: Dictionary = ctx.get("predicates", {})
			var name: StringName = term["predicate_name"]
			if not predicates.has(name):
				return {"result": Result.FAULT, "fault": {
					"code": EQError.CONDITION_PREDICATE_UNREGISTERED,
					"message": "predicate %s is not registered" % name,
					"context": {"condition_id": String(term["condition_id"])},
				}}
			var callable: Callable = predicates[name]
			var holds := bool(callable.call(ctx.get("view", {}))) == true
			return {"result": Result.YES if holds else Result.NO, "fault": null}
		_:
			return {"result": Result.FAULT, "fault": {
				"code": EQError.CONDITION_LINE_UNKNOWN,
				"message": "malformed bound term",
				"context": {"condition_id": String(term.get("condition_id", ""))},
			}}


## AND over all bound terms at this evaluation point; empty = vacuously YES.
## Returns {result: Result, fault: Dictionary|null}.
static func solve_holds(terms: Array, ctx: Dictionary) -> Dictionary:
	for term in terms:
		var r := term_holds(term, ctx)
		if int(r["result"]) != Result.YES:
			return r
	return {"result": Result.YES, "fault": null}


## OR over bound terms in declared order; the first holding term names closed_by.
## Returns {result: Result, closed_by: StringName, fault: Dictionary|null}.
static func invalidation_check(terms: Array, ctx: Dictionary) -> Dictionary:
	for term in terms:
		var r := term_holds(term, ctx)
		if int(r["result"]) == Result.FAULT:
			return {"result": Result.FAULT, "closed_by": &"", "fault": r["fault"]}
		if int(r["result"]) == Result.YES:
			return {"result": Result.YES, "closed_by": term["condition_id"], "fault": null}
	return {"result": Result.NO, "closed_by": &"", "fault": null}


## Invalidation-wins (Q28, uniform): both holding at the same point invalidates.
## A fault on either side is Outcome.FAULT (the pipeline decides dev/shipped).
static func decide(solve: Dictionary, invalidation: Dictionary) -> int:
	if int(invalidation["result"]) == Result.FAULT or int(solve["result"]) == Result.FAULT:
		return Outcome.FAULT
	if int(invalidation["result"]) == Result.YES:
		return Outcome.INVALIDATE
	if int(solve["result"]) == Result.YES:
		return Outcome.RESOLVE
	return Outcome.WAIT
