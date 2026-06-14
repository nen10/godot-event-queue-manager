extends RefCounted
## EQM-030: fixed round policy — battle-start initiative order, round refresh,
## equal-initiative tie-break (registration order), removed-actor skip.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQFixedRoundPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd")


static func run(t) -> void:
	_test_battle_start_and_refresh(t)
	_test_equal_initiative_tiebreak(t)
	_test_removed_actor_skipped(t)


## Registers an actor with an initiative and returns nothing.
static func _add(rt, id: StringName, initiative: int) -> void:
	var s = rt.register_actor(id)
	s.data["initiative"] = initiative


## Advances `count` turns, finishing each via the policy, returning the actor_id
## order.
static func _play(rt, pol, count: int) -> Array:
	var order: Array = []
	for _i in count:
		var e = rt.advance()
		if e == null:
			break
		order.append(e.actor_id)
		pol.on_turn_finished(rt, e.actor_id, EQActionResult.new(0, 0))
	return order


static func _test_battle_start_and_refresh(t) -> void:
	var rt := EQRuntime.new()
	var pol := EQFixedRoundPolicy.new()
	_add(rt, &"slow", 1)
	_add(rt, &"fast", 9)
	_add(rt, &"mid", 5)
	pol.seed(rt, rt.registry.actor_ids())
	var order := _play(rt, pol, 6)  # two rounds of three
	t.eq(order, [&"fast", &"mid", &"slow", &"fast", &"mid", &"slow"], "battle-start by initiative DESC, then identical round refresh")


static func _test_equal_initiative_tiebreak(t) -> void:
	var rt := EQRuntime.new()
	var pol := EQFixedRoundPolicy.new()
	_add(rt, &"a", 5)
	_add(rt, &"b", 5)  # equal initiative -> registration order decides
	_add(rt, &"c", 5)
	pol.seed(rt, rt.registry.actor_ids())
	var order := _play(rt, pol, 3)
	t.eq(order, [&"a", &"b", &"c"], "equal initiative resolves in registration order")


static func _test_removed_actor_skipped(t) -> void:
	var rt := EQRuntime.new(null, EQRuntime.Mode.SHIPPED)
	rt.emit_engine_diagnostics = false
	var pol := EQFixedRoundPolicy.new()
	_add(rt, &"a", 9)
	_add(rt, &"b", 5)
	_add(rt, &"c", 1)
	pol.seed(rt, rt.registry.actor_ids())
	t.eq(rt.advance().actor_id, &"a", "a acts first")
	pol.on_turn_finished(rt, &"a", EQActionResult.new(0, 0))
	rt.registry.unregister(&"b")          # b leaves mid-round
	var rest := _play(rt, pol, 5)
	t.ok(not rest.has(&"b"), "removed actor gets no further turns")
	t.ok(rest.has(&"a") and rest.has(&"c"), "remaining actors keep acting")
	t.ok(rt.trace_jsonl().contains("invalid_event_skipped"), "removed actor's pending turn skipped in trace")
