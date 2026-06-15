extends RefCounted
## EQM-051: reservation pipeline — immediate resolves at delay 0, prepared after
## delay, wait schedules a ready reservation, operation causes a target
## reservation, reaction preparation is armed (not scheduled).

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")


static func run(t) -> void:
	_test_immediate(t)
	_test_prepared(t)
	_test_wait_schedules_ready(t)
	_test_operation_causes_target(t)
	_test_reaction_armed(t)


static func _def(kind: int, delay: int = 0) -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = kind
	d.delay = delay
	return d


static func _rr_with(actors: Array):
	var rr := EQReservationRuntime.new()
	for a in actors:
		rr.runtime.register_actor(a)
	return rr


static func _test_immediate(t) -> void:
	var rr = _rr_with([&"hero"])
	var res := EQReservation.new(&"hero", _def(EQActionDefinition.Kind.IMMEDIATE, 0))
	var id := rr.submit(res)
	t.ok(id > 0, "immediate submit scheduled")
	t.eq(rr.runtime.scheduler.peek_next().due_tick, 0, "immediate scheduled at delay 0 (current tick)")
	var done = rr.resolve_next()
	t.eq(done.status, EQReservation.Status.RESOLVED, "immediate resolves")
	t.eq(rr.runtime.scheduler.current_tick, 0, "resolved at tick 0")


static func _test_prepared(t) -> void:
	var rr = _rr_with([&"hero"])
	rr.submit(EQReservation.new(&"hero", _def(EQActionDefinition.Kind.PREPARED, 5)))
	t.eq(rr.runtime.scheduler.peek_next().due_tick, 5, "prepared scheduled at current_tick + delay")
	var done = rr.resolve_next()
	t.eq(done.status, EQReservation.Status.RESOLVED, "prepared resolves after delay")
	t.eq(rr.runtime.scheduler.current_tick, 5, "clock advanced to the prepared delay")


static func _test_wait_schedules_ready(t) -> void:
	var rr = _rr_with([&"hero"])
	var wait := EQReservation.new(&"hero", _def(EQActionDefinition.Kind.WAIT, 3))
	rr.submit(wait)
	t.eq(wait.status, EQReservation.Status.RESOLVED, "wait itself resolves immediately")
	var pend := rr.pending()
	t.eq(pend.size(), 1, "wait scheduled exactly one follow-up reservation")
	t.eq(pend[0].definition.kind, EQActionDefinition.Kind.READY, "wait schedules a READY reservation")
	t.eq(rr.runtime.scheduler.peek_next().due_tick, 3, "ready reservation scheduled after the wait delay")


static func _test_operation_causes_target(t) -> void:
	var rr = _rr_with([&"attacker", &"target"])
	var op_def := _def(EQActionDefinition.Kind.OPERATION, 0)
	op_def.operation_target_tag = &"counter"
	var op := EQReservation.new(&"attacker", op_def)
	op.target_id = &"target"
	rr.submit(op)
	t.eq(rr.armed_for(&"target").size(), 0, "no target reservation before the operation resolves")
	rr.resolve_next()
	var armed := rr.armed_for(&"target")
	t.eq(armed.size(), 1, "operation resolution causes a reservation on the target")
	t.ok(armed[0].definition.tags.has(&"counter"), "caused reservation carries the operation's target tag")


static func _test_reaction_armed(t) -> void:
	var rr = _rr_with([&"hero"])
	var rdef := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	rdef.duration = EQActionDefinition.DURATION_UNLIMITED
	var id := rr.submit(EQReservation.new(&"hero", rdef))
	t.eq(id, -1, "reaction preparation is not scheduled")
	t.ok(rr.runtime.scheduler.is_empty(), "no scheduler event for an armed reaction")
	t.eq(rr.armed_for(&"hero").size(), 1, "reaction preparation is armed")
