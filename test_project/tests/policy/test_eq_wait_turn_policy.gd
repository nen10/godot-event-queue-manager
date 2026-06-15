extends RefCounted
## EQM-041: wait-turn policy (TO/FFT) — instant resolve to the next-ready unit,
## action cost sets the next wait, and equal-wait tie-break (agility, then
## registration order).

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQWaitTurnPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_wait_turn_policy.gd")


static func run(t) -> void:
	_test_instant_resolve(t)
	_test_action_cost_sets_next_wait(t)
	_test_equal_wait_tiebreak(t)


static func _add(rt, id: StringName, wait: int, agility: int = 0) -> void:
	var s = rt.register_actor(id)
	s.data["wait"] = wait
	s.data["agility"] = agility


static func _test_instant_resolve(t) -> void:
	var rt := EQRuntime.new()
	var pol := EQWaitTurnPolicy.new()
	_add(rt, &"a", 5)
	_add(rt, &"b", 3)
	_add(rt, &"c", 8)
	pol.seed(rt, rt.registry.actor_ids())
	var e1 = rt.advance()
	t.eq(e1.actor_id, &"b", "smallest wait acts first")
	t.eq(rt.scheduler.current_tick, 3, "clock jumps straight to the next-ready unit (no idle ticks)")
	var e2 = rt.advance()
	t.eq(e2.actor_id, &"a", "next-smallest wait second")
	t.eq(rt.scheduler.current_tick, 5, "clock jumps to 5")
	t.eq(rt.advance().actor_id, &"c", "largest wait last")
	t.eq(rt.scheduler.current_tick, 8, "clock jumps to 8")


static func _test_action_cost_sets_next_wait(t) -> void:
	var rt := EQRuntime.new()
	var pol := EQWaitTurnPolicy.new()
	_add(rt, &"u", 2)
	pol.seed(rt, rt.registry.actor_ids())
	rt.advance()  # u acts at tick 2
	pol.on_turn_finished(rt, &"u", EQActionResult.new(10, 0))   # heavy -> next wait 10
	var heavy_next := rt.scheduler.peek_next().due_tick - rt.scheduler.current_tick
	t.eq(heavy_next, 10, "action cost becomes the next wait (heavy)")

	var rt2 := EQRuntime.new()
	var pol2 := EQWaitTurnPolicy.new()
	rt2.register_actor(&"u").data["wait"] = 2
	pol2.seed(rt2, rt2.registry.actor_ids())
	rt2.advance()
	pol2.on_turn_finished(rt2, &"u", EQActionResult.new(3, 0))  # light -> next wait 3
	var light_next := rt2.scheduler.peek_next().due_tick - rt2.scheduler.current_tick
	t.ok(light_next < heavy_next, "a lighter action yields a shorter next wait (%d < %d)" % [light_next, heavy_next])


static func _test_equal_wait_tiebreak(t) -> void:
	# equal wait -> higher agility first, then registration order
	var rt := EQRuntime.new()
	var pol := EQWaitTurnPolicy.new()
	_add(rt, &"low", 5, 1)
	_add(rt, &"high", 5, 9)   # same wait, higher agility -> first
	pol.seed(rt, rt.registry.actor_ids())
	t.eq(rt.advance().actor_id, &"high", "equal wait: higher agility acts first")
	t.eq(rt.advance().actor_id, &"low", "then the lower-agility unit")

	# equal wait AND equal agility -> registration order (sequence)
	var rt2 := EQRuntime.new()
	var pol2 := EQWaitTurnPolicy.new()
	_add(rt2, &"first", 4, 0)
	_add(rt2, &"second", 4, 0)
	pol2.seed(rt2, rt2.registry.actor_ids())
	t.eq(rt2.advance().actor_id, &"first", "equal wait+agility: registration order decides")
	t.eq(rt2.advance().actor_id, &"second", "registration order second")
