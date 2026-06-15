extends RefCounted
## EQM-040: energy policy — threshold readiness, action cost, speed differences,
## wait, and energy carry-over.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQEnergyPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_energy_policy.gd")


static func run(t) -> void:
	_test_threshold_readiness(t)
	_test_action_cost(t)
	_test_faster_more_turns(t)
	_test_carry_over(t)


static func _rt_with(speed: int):
	var rt := EQRuntime.new()
	var pol := EQEnergyPolicy.new()
	rt.register_actor(&"u").data["speed"] = speed
	pol.seed(rt, rt.registry.actor_ids())
	return [rt, pol]


## delay = (next due_tick - current_tick) for a fresh actor finishing `cost`.
static func _delay_after(speed: int, cost: int) -> int:
	var pair = _rt_with(speed)
	var rt = pair[0]
	var pol = pair[1]
	rt.advance()
	pol.on_turn_finished(rt, &"u", EQActionResult.new(cost, 0))
	return rt.scheduler.peek_next().due_tick - rt.scheduler.current_tick


static func _test_threshold_readiness(t) -> void:
	# speed 10, threshold 100 -> first turn at ceil(100/10) = 10
	var pair = _rt_with(10)
	var rt = pair[0]
	t.eq(rt.scheduler.peek_next().due_tick, 10, "first turn when energy reaches threshold (ceil(threshold/speed))")
	t.eq(rt.advance().actor_id, &"u", "actor acts at readiness")


static func _test_action_cost(t) -> void:
	var normal := _delay_after(10, 100)
	var heavy := _delay_after(10, 150)
	var wait := _delay_after(10, 50)
	t.ok(heavy > normal, "heavy action -> longer refill (heavy=%d normal=%d)" % [heavy, normal])
	t.ok(wait < normal, "wait -> shorter refill (wait=%d normal=%d)" % [wait, normal])


static func _test_faster_more_turns(t) -> void:
	var rt := EQRuntime.new()
	var pol := EQEnergyPolicy.new()
	rt.register_actor(&"fast").data["speed"] = 20
	rt.register_actor(&"slow").data["speed"] = 10
	pol.seed(rt, rt.registry.actor_ids())
	var fast := 0
	var slow := 0
	for _i in 9:
		var e = rt.advance()
		if e == null:
			break
		if e.actor_id == &"fast":
			fast += 1
		else:
			slow += 1
		pol.on_turn_finished(rt, e.actor_id, EQActionResult.new(0, 0))
	t.ok(fast > slow, "faster actor takes more turns (fast=%d slow=%d)" % [fast, slow])


static func _test_carry_over(t) -> void:
	# A wait (cost 50) leaves 50 energy banked, so the next refill is shorter than
	# a fresh full refill; the carried energy is visible on the actor.
	var pair = _rt_with(10)
	var rt = pair[0]
	var pol = pair[1]
	rt.advance()                                           # acts with energy 100
	pol.on_turn_finished(rt, &"u", EQActionResult.new(50, 0))  # wait: spend 50, carry 50
	t.eq(rt.registry.get_state(&"u").data["energy"], 50, "remainder carried over (100 - 50)")
	var wait_delay: int = rt.scheduler.peek_next().due_tick - rt.scheduler.current_tick
	t.eq(wait_delay, 5, "carry 50 + speed 10 -> only 5 ticks to refill (vs 10 fresh)")
