extends RefCounted
## EQM-031: CTB policy — faster actor takes more turns, heavy action delays the
## next turn, wait shortens it, and haste/slow (speed change) shifts the next turn.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQCTBPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_ctb_policy.gd")


static func run(t) -> void:
	_test_faster_more_turns(t)
	_test_action_cost_delay(t)
	_test_haste_slow(t)
	_test_delay_is_int_and_monotonic(t)


static func _add(rt, id: StringName, speed: int) -> void:
	rt.register_actor(id).data["speed"] = speed


## Returns the delay (next due_tick - current_tick) for a fresh actor of `speed`
## finishing an action of `cost`.
static func _delay_after(speed: int, cost: int) -> int:
	var rt := EQRuntime.new()
	var pol := EQCTBPolicy.new()
	_add(rt, &"u", speed)
	pol.seed(rt, rt.registry.actor_ids())
	rt.advance()  # resolve the seeded turn; current_tick is now the seed delay
	pol.on_turn_finished(rt, &"u", EQActionResult.new(cost, 0))
	return rt.scheduler.peek_next().due_tick - rt.scheduler.current_tick


static func _test_faster_more_turns(t) -> void:
	var rt := EQRuntime.new()
	var pol := EQCTBPolicy.new()
	_add(rt, &"fast", 20)
	_add(rt, &"slow", 10)
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
		pol.on_turn_finished(rt, e.actor_id, EQActionResult.new(0, 0))  # normal action
	t.ok(fast > slow, "faster actor takes more turns (fast=%d slow=%d)" % [fast, slow])
	t.ok(fast >= slow * 2 - 1, "roughly proportional to speed (2x)")


static func _test_action_cost_delay(t) -> void:
	var normal := _delay_after(10, 100)
	var heavy := _delay_after(10, 200)
	var wait := _delay_after(10, 50)
	t.ok(heavy > normal, "heavy action delays the next turn (heavy=%d normal=%d)" % [heavy, normal])
	t.ok(wait < normal, "wait shortens the next turn (wait=%d normal=%d)" % [wait, normal])


static func _test_haste_slow(t) -> void:
	var normal := _delay_after(10, 100)
	var hasted := _delay_after(20, 100)   # haste = higher speed
	var slowed := _delay_after(5, 100)    # slow = lower speed
	t.ok(hasted < normal, "haste (higher speed) brings the next turn sooner")
	t.ok(slowed > normal, "slow (lower speed) pushes the next turn later")


static func _test_delay_is_int_and_monotonic(t) -> void:
	var d := _delay_after(10, 100)
	t.eq(typeof(d), TYPE_INT, "delay is an integer (no float in ordering)")
	t.ok(d >= 1, "delay is at least 1 (queue always progresses)")
	# determinism: same speed+cost -> same delay
	t.eq(_delay_after(13, 77), _delay_after(13, 77), "same speed+cost is deterministic")
