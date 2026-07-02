extends RefCounted
## EQM-115: the §7.1 ordering hook — acceptance orders simultaneous arrivals
## (TO "lower base WT acts first"); fallback = issuance order; invalid
## permutations are stable faults; views are serializable; output is traced and
## replay-deterministic (Q20 golden guarantee).

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQSaveAdapter := preload("res://addons/event_queue_manager/runtime/eq_save_adapter.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_default_is_issuance_order(t)
	_test_hook_orders_simultaneous_arrivals(t)
	_test_views_are_serializable(t)
	_test_invalid_permutation(t)
	_test_hook_orders_fired_reactions(t)
	_test_replay_determinism(t)


## Three actors whose CT lines all reach the threshold on the same tick; base_wt
## differs so a TO-style hook can reorder them against issuance order.
static func _simultaneous_setup(hook = null, shipped: bool = false) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	if shipped:
		rr.runtime.set_mode(rr.runtime.Mode.SHIPPED)
	var actors := [[&"a_slow", 30], [&"b_fast", 10], [&"c_mid", 20]]  # issuance order
	for pair in actors:
		rr.runtime.register_actor(pair[0])
		rr.runtime.registry.get_state(pair[0]).data["base_wt"] = pair[1]
		rr.lines.issue(StringName("ct.%s" % pair[0]), 0, 10)
		var d := EQActionDefinition.new()
		d.kind = EQActionDefinition.Kind.IMMEDIATE
		var spec := EQConditionSpec.new()
		spec.type = EQConditionSpec.Type.LINE_THRESHOLD
		spec.line_id = StringName("ct.%s" % pair[0])
		spec.threshold = 10
		d.solve_conditions = [spec]
		rr.submit(EQReservation.new(pair[0], d))
	if hook != null:
		rr.set_order_hook(hook)
	rr.step_tick()  # every line reaches 10 together -> simultaneous arrival
	return rr


static func _resolution_order(rr: EQReservationRuntime) -> Array:
	var out := []
	for _i in 6:
		var res = rr.resolve_next()
		if res == null:
			break
		out.append(res.actor_id)
	return out


static func _wt_hook() -> Callable:
	return func(candidates: Array) -> Array:
		var idx := range(candidates.size())
		idx.sort_custom(func(x, y): return int(candidates[x]["stats"]["base_wt"]) < int(candidates[y]["stats"]["base_wt"]))
		return idx


static func _test_default_is_issuance_order(t) -> void:
	var rr := _simultaneous_setup()
	t.eq(_resolution_order(rr), [&"a_slow", &"b_fast", &"c_mid"], "without a hook, simultaneous arrivals resolve in issuance order (the final fallback)")
	t.ok(not ('"kind":"order_hook_applied"' in rr.runtime.trace_jsonl()), "no hook, no hook trace")


static func _test_hook_orders_simultaneous_arrivals(t) -> void:
	var rr := _simultaneous_setup(_wt_hook())
	t.eq(_resolution_order(rr), [&"b_fast", &"c_mid", &"a_slow"], "the hook orders simultaneous arrivals (TO: lower base WT first)")
	var jsonl := rr.runtime.trace_jsonl()
	t.ok('"kind":"order_hook_applied"' in jsonl, "hook application is traced")
	t.ok('"order":[1,2,0]' in jsonl, "the chosen permutation participates in the canonical trace (Q20)")


static func _test_views_are_serializable(t) -> void:
	var captured := []
	var rr := _simultaneous_setup(func(candidates: Array) -> Array:
		captured.append_array(candidates)
		return range(candidates.size()))
	_resolution_order(rr)
	t.eq(captured.size(), 3, "hook received one view per candidate")
	t.ok(not EQSaveAdapter.contains_live_object(captured[0]), "candidate views contain no live object references (Q20)")
	for key in ["index", "actor", "stats", "tags", "priority", "nest_level", "lines"]:
		t.ok(captured[0].has(key), "view carries the %s field" % key)


static func _test_invalid_permutation(t) -> void:
	var rr := _simultaneous_setup(func(_c: Array) -> Array: return [0, 0, 1], true)  # duplicate; shipped observes the fallback (dev halts)
	t.eq(_resolution_order(rr), [&"a_slow", &"b_fast", &"c_mid"], "an invalid permutation falls back to issuance order")
	t.eq(rr.runtime.faults.back()["code"], EQError.ORDER_HOOK_INVALID, "...and records a stable fault (never silently adopted)")


static func _test_hook_orders_fired_reactions(t) -> void:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for pair in [[&"guard_slow", 30], [&"guard_fast", 10], [&"orc", 0]]:
		rr.runtime.register_actor(pair[0])
		rr.runtime.registry.get_state(pair[0]).data["base_wt"] = pair[1]
	rr.set_order_hook(_wt_hook())
	for owner in [&"guard_slow", &"guard_fast"]:
		var rdef := EQActionDefinition.new()
		rdef.kind = EQActionDefinition.Kind.REACTION_PREPARATION
		rdef.duration = EQActionDefinition.DURATION_UNLIMITED
		var c := EQCondition.new()
		c.require_tags = [&"damage"]
		c.match_target = &"orc"
		rr.submit(EQReservation.new(owner, rdef), c)
	var atk := EQActionDefinition.new()
	atk.kind = EQActionDefinition.Kind.IMMEDIATE
	atk.tags = [&"damage"]
	var attack := EQReservation.new(&"orc", atk)
	attack.target_id = &"orc"
	rr.submit(attack)
	rr.resolve_next()  # the attack; both guards fire simultaneously
	var first = rr.resolve_next()
	t.eq(first.actor_id, &"guard_fast", "simultaneously fired reactions are also hook-ordered")


static func _test_replay_determinism(t) -> void:
	var a := _simultaneous_setup(_wt_hook())
	_resolution_order(a)
	var b := _simultaneous_setup(_wt_hook())
	_resolution_order(b)
	t.eq(a.runtime.trace_jsonl(), b.runtime.trace_jsonl(), "identical input replays to a byte-identical trace incl. the hook output (golden guarantee)")
