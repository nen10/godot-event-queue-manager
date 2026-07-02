extends RefCounted
## EQM-111: EQConditionEval — level-triggered AND / OR / invalidation-wins /
## closed_by / faults-as-values (SEM §5.4) and the runtime predicate registry
## (SEM §5.5).

const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQConditionEval := preload("res://addons/event_queue_manager/runtime/eq_condition_eval.gd")
const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_bind(t)
	_test_line_terms(t)
	_test_level_semantics(t)
	_test_solve_and(t)
	_test_invalidation_or(t)
	_test_invalidation_wins(t)
	_test_predicates(t)
	_test_registry(t)


static func _spec(line: StringName, threshold: int, cmp: int = EQConditionSpec.Comparison.GE, relative := false) -> EQConditionSpec:
	var s := EQConditionSpec.new()
	s.type = EQConditionSpec.Type.LINE_THRESHOLD
	s.line_id = line
	s.threshold = threshold
	s.comparison = cmp
	s.relative = relative
	return s


static func _test_bind(t) -> void:
	var ctx := {"lines": {&"tick": 10}}
	var absolute := EQConditionEval.bind(_spec(&"tick", 15), "solve", 0, ctx)
	t.eq(absolute["threshold"], 15, "absolute bind keeps the declared threshold")
	t.eq(absolute["condition_id"], &"solve:0", "unset condition_id binds deterministically to <group>:<index>")

	var relative := EQConditionEval.bind(_spec(&"tick", 5, EQConditionSpec.Comparison.GE, true), "invalidation", 1, ctx)
	t.eq(relative["threshold"], 15, "relative bind fixes threshold = bind-time value + declared")

	var named := _spec(&"tick", 5)
	named.condition_id = &"duration"
	t.eq(EQConditionEval.bind(named, "invalidation", 0, ctx)["condition_id"], &"duration", "declared condition_id wins over the deterministic default")

	var counter := EQConditionSpec.new()
	counter.type = EQConditionSpec.Type.COUNTER
	counter.counter_start = 3
	var bound := EQConditionEval.bind(counter, "invalidation", 2, ctx, &"counter#7")
	t.eq(bound["line_id"], &"counter#7", "COUNTER binds to its runtime counter line")
	t.eq(bound["threshold"], 0, "COUNTER binds as (counter_line, 0, LE)")
	t.eq(bound["comparison"], EQConditionSpec.Comparison.LE, "COUNTER comparison is LE")

	var unbound := EQConditionEval.bind(counter, "invalidation", 2, ctx)
	var r := EQConditionEval.term_holds(unbound, ctx)
	t.eq(r["result"], EQConditionEval.Result.FAULT, "COUNTER bind without a counter line is a fault, not silent false")


static func _test_line_terms(t) -> void:
	var ctx := {"lines": {&"ct": 100}}
	var ge := EQConditionEval.bind(_spec(&"ct", 100), "solve", 0, ctx)
	t.eq(EQConditionEval.term_holds(ge, ctx)["result"], EQConditionEval.Result.YES, "GE holds at equality")
	var lt := EQConditionEval.bind(_spec(&"ct", 100, EQConditionSpec.Comparison.LT), "solve", 0, ctx)
	t.eq(EQConditionEval.term_holds(lt, ctx)["result"], EQConditionEval.Result.NO, "LT does not hold at equality")

	var unknown := EQConditionEval.bind(_spec(&"missing", 1), "solve", 0, ctx)
	var r := EQConditionEval.term_holds(unknown, ctx)
	t.eq(r["result"], EQConditionEval.Result.FAULT, "unknown line is a fault, never treated as 0")
	t.eq(r["fault"]["code"], EQError.CONDITION_LINE_UNKNOWN, "unknown line fault carries the stable code")


static func _test_level_semantics(t) -> void:
	# level, not latched: the same term re-evaluated after the line drops no longer holds
	var term := EQConditionEval.bind(_spec(&"ap", 5), "solve", 0, {})
	t.eq(EQConditionEval.term_holds(term, {"lines": {&"ap": 6}})["result"], EQConditionEval.Result.YES, "holds while the level is reached")
	t.eq(EQConditionEval.term_holds(term, {"lines": {&"ap": 4}})["result"], EQConditionEval.Result.NO, "no longer holds after the level drops (level-triggered, Q29)")


static func _test_solve_and(t) -> void:
	var a := EQConditionEval.bind(_spec(&"ap", 5), "solve", 0, {})
	var b := EQConditionEval.bind(_spec(&"ct", 100), "solve", 1, {})
	t.eq(EQConditionEval.solve_holds([a, b], {"lines": {&"ap": 5, &"ct": 100}})["result"], EQConditionEval.Result.YES, "AND holds when all terms hold at the same point")
	t.eq(EQConditionEval.solve_holds([a, b], {"lines": {&"ap": 5, &"ct": 99}})["result"], EQConditionEval.Result.NO, "AND fails when any term fails")
	t.eq(EQConditionEval.solve_holds([], {"lines": {}})["result"], EQConditionEval.Result.YES, "empty solve set is vacuously true")


static func _test_invalidation_or(t) -> void:
	var hp := _spec(&"hp", 0, EQConditionSpec.Comparison.LE)
	hp.condition_id = &"owner_dead"
	var dur := _spec(&"tick", 20)
	dur.condition_id = &"duration"
	var terms := [
		EQConditionEval.bind(hp, "invalidation", 0, {}),
		EQConditionEval.bind(dur, "invalidation", 1, {}),
	]
	var none := EQConditionEval.invalidation_check(terms, {"lines": {&"hp": 5, &"tick": 10}})
	t.eq(none["result"], EQConditionEval.Result.NO, "OR does not hold while no term holds")
	var second := EQConditionEval.invalidation_check(terms, {"lines": {&"hp": 5, &"tick": 20}})
	t.eq(second["closed_by"], &"duration", "closed_by names the holding term")
	var both := EQConditionEval.invalidation_check(terms, {"lines": {&"hp": 0, &"tick": 20}})
	t.eq(both["closed_by"], &"owner_dead", "when several hold, the first declared term names closed_by (deterministic)")


static func _test_invalidation_wins(t) -> void:
	var yes := {"result": EQConditionEval.Result.YES, "fault": null}
	var no := {"result": EQConditionEval.Result.NO, "fault": null}
	var inv_yes := {"result": EQConditionEval.Result.YES, "closed_by": &"duration", "fault": null}
	var inv_no := {"result": EQConditionEval.Result.NO, "closed_by": &"", "fault": null}
	t.eq(EQConditionEval.decide(yes, inv_yes), EQConditionEval.Outcome.INVALIDATE, "both holding at the same point invalidates (invalidation-wins, Q28)")
	t.eq(EQConditionEval.decide(yes, inv_no), EQConditionEval.Outcome.RESOLVE, "solve alone resolves")
	t.eq(EQConditionEval.decide(no, inv_no), EQConditionEval.Outcome.WAIT, "neither holds -> keep waiting")
	var fault := {"result": EQConditionEval.Result.FAULT, "fault": {"code": EQError.CONDITION_LINE_UNKNOWN, "message": ""}}
	t.eq(EQConditionEval.decide(fault, inv_no), EQConditionEval.Outcome.FAULT, "a fault is surfaced, never swallowed")


static func _test_predicates(t) -> void:
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.NAMED_PREDICATE
	spec.predicate_name = &"target_visible"
	var term := EQConditionEval.bind(spec, "solve", 0, {})

	var seen := {}
	var predicates := {&"target_visible": func(view: Dictionary) -> bool:
		seen["view"] = view
		return view.get("visible", false)}
	var ctx := {"predicates": predicates, "view": {"visible": true, "target": "orc"}}
	t.eq(EQConditionEval.term_holds(term, ctx)["result"], EQConditionEval.Result.YES, "registered predicate evaluates the view")
	t.eq(seen["view"]["target"], "orc", "predicate receives the serializable view dict")
	ctx["view"] = {"visible": false}
	t.eq(EQConditionEval.term_holds(term, ctx)["result"], EQConditionEval.Result.NO, "predicate false -> term does not hold")

	var missing := EQConditionEval.term_holds(term, {"predicates": {}, "view": {}})
	t.eq(missing["result"], EQConditionEval.Result.FAULT, "unregistered predicate is a fault (stable error, SEM §5.5)")
	t.eq(missing["fault"]["code"], EQError.CONDITION_PREDICATE_UNREGISTERED, "unregistered predicate fault carries the stable code")


static func _test_registry(t) -> void:
	var rt := EQRuntime.new()
	rt.emit_engine_diagnostics = false
	t.ok(rt.register_predicate(&"target_visible", func(_v): return true), "register_predicate accepts a named predicate")
	t.ok(rt.has_predicate(&"target_visible"), "has_predicate sees the registration")
	t.ok(rt.register_predicate(&"target_visible", func(_v): return false), "re-registration replaces (idempotent setup)")
	t.eq(bool((rt.predicates()[&"target_visible"] as Callable).call({})), false, "predicates() exposes the latest registration")

	t.ok(not rt.register_predicate(&"", func(_v): return true), "empty predicate name is rejected")
	t.ok(not rt.faults.is_empty(), "empty-name rejection is a recorded fault, not silent")
	var copy := rt.predicates()
	copy[&"hacked"] = func(_v): return true
	t.ok(not rt.has_predicate(&"hacked"), "predicates() returns a copy; registry cannot be mutated from outside")
