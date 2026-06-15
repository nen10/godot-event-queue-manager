extends RefCounted
## EQM-052: Action Resolution AP/ready model — a ready reservation grants the
## turn after the AP-recovery delay, AP spend/recovery is deterministic, and the
## turn closes through wait.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQActionResolutionPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")


static func run(t) -> void:
	_test_ready_after_recovery(t)
	_test_ap_deterministic(t)
	_test_turn_closes_through_wait(t)
	_test_ready_reservation_object(t)


static func _rt():
	var rt := EQRuntime.new()
	var pol := EQActionResolutionPolicy.new()  # ap_max 100, recovery 10
	rt.register_actor(&"hero").data["ap_recovery"] = 10
	pol.seed(rt, rt.registry.actor_ids())
	return [rt, pol]


static func _test_ready_after_recovery(t) -> void:
	var pair = _rt()
	var rt = pair[0]
	# first ready turn after AP charges to ap_max: ceil(100/10) = 10
	t.eq(rt.scheduler.peek_next().due_tick, 10, "first ready turn after AP recovery delay (ceil(ap_max/recovery))")
	t.eq(rt.advance().actor_id, &"hero", "the ready reservation grants the turn")


static func _test_ap_deterministic(t) -> void:
	var pair = _rt()
	var rt = pair[0]
	var pol = pair[1]
	rt.advance()  # first turn at tick 10
	pol.on_turn_finished(rt, &"hero", EQActionResult.new(100, 0))  # full action
	t.eq(rt.registry.get_state(&"hero").data["ap"], 0, "AP after a full-cost turn is ap_max - cost (deterministic)")
	var full_delay: int = rt.scheduler.peek_next().due_tick - rt.scheduler.current_tick
	t.eq(full_delay, 10, "next ready after recovering the spent AP: ceil(100/10)")
	# same inputs reproduce the same delay
	var pair2 = _rt()
	pair2[0].advance()
	pair2[1].on_turn_finished(pair2[0], &"hero", EQActionResult.new(100, 0))
	t.eq(pair2[0].scheduler.peek_next().due_tick - pair2[0].scheduler.current_tick, full_delay, "AP recovery is deterministic")


static func _test_turn_closes_through_wait(t) -> void:
	var pair = _rt()
	var rt = pair[0]
	var pol = pair[1]
	rt.advance()
	var before: int = rt.scheduler.size()
	pol.on_turn_finished(rt, &"hero", EQActionResult.new(30, 0))  # a wait closes the turn cheaply
	t.eq(rt.scheduler.size(), before + 1, "closing the turn (wait) schedules the next ready")
	var wait_delay: int = rt.scheduler.peek_next().due_tick - rt.scheduler.current_tick
	t.eq(wait_delay, 3, "a cheaper wait recovers sooner: ceil(30/10) = 3")
	t.eq(rt.registry.get_state(&"hero").data["ap"], 70, "AP after a 30-cost wait is 70")


static func _test_ready_reservation_object(t) -> void:
	var pair = _rt()
	var rt = pair[0]
	var pol = pair[1]
	var res = pol.ready_reservation_for(rt, &"hero", 50)
	t.eq(res.definition.kind, EQActionDefinition.Kind.READY, "ready_reservation_for returns a READY reservation")
	t.eq(res.definition.delay, 5, "ready reservation delay = AP-recovery delay (ceil(50/10))")
	t.eq(res.actor_id, &"hero", "ready reservation is for the actor")
