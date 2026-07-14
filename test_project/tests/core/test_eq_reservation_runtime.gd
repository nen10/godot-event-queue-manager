extends RefCounted
## EQM-051: reservation pipeline — immediate resolves at delay 0, prepared after
## delay, wait schedules a ready reservation, operation causes a target
## reservation, reaction preparation is armed (not scheduled).

const EQReservationRuntime := preload(
	"res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd"
)
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_immediate(t)
	_test_prepared(t)
	_test_wait_schedules_ready(t)
	_test_operation_causes_target(t)
	_test_operation_rejects_missing_or_unknown_target(t)
	_test_operation_does_not_ghost_arm_removed_target(t)
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
	t.eq(
		rr.runtime.scheduler.peek_next().due_tick,
		0,
		"immediate scheduled at delay 0 (current tick)"
	)
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
	t.eq(
		pend[0].definition.kind, EQActionDefinition.Kind.READY, "wait schedules a READY reservation"
	)
	t.eq(
		rr.runtime.scheduler.peek_next().due_tick,
		3,
		"ready reservation scheduled after the wait delay"
	)


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
	t.ok(
		armed[0].definition.tags.has(&"counter"),
		"caused reservation carries the operation's target tag"
	)


static func _test_operation_rejects_missing_or_unknown_target(t) -> void:
	var missing = _rr_with([&"attacker"])
	missing.runtime.emit_engine_diagnostics = false
	var missing_def := _def(EQActionDefinition.Kind.OPERATION, 0)
	missing_def.operation_target_tag = &"counter"
	var missing_op := EQReservation.new(&"attacker", missing_def)
	t.eq(missing.submit(missing_op), -1, "operation with empty target_id is rejected")
	t.eq(
		missing.runtime.faults.back()["code"],
		EQError.RESERVATION_OPERATION_NEEDS_TARGET,
		"empty target_id uses the stable operation target error"
	)
	t.ok(missing.runtime.scheduler.is_empty(), "empty target creates no scheduled work")
	t.eq(
		missing_op.effect_commit_result_version,
		-1,
		"rejected empty target is not effect-mode bound"
	)

	var unknown = _rr_with([&"attacker"])
	unknown.runtime.emit_engine_diagnostics = false
	var unknown_def := _def(EQActionDefinition.Kind.OPERATION, 0)
	unknown_def.operation_target_tag = &"counter"
	var unknown_op := EQReservation.new(&"attacker", unknown_def)
	unknown_op.target_id = &"typo_target"
	t.eq(unknown.submit(unknown_op), -1, "operation with unknown target is rejected")
	t.eq(
		unknown.runtime.faults.back()["code"],
		EQError.RUNTIME_SCHEDULE_UNREGISTERED_ACTOR,
		"unknown target uses the stable scheduling error"
	)
	t.ok(unknown.runtime.scheduler.is_empty(), "unknown target creates no scheduled work")
	t.eq(
		unknown_op.effect_commit_result_version,
		-1,
		"rejected unknown target is not effect-mode bound"
	)


static func _test_operation_does_not_ghost_arm_removed_target(t) -> void:
	var rr = _rr_with([&"attacker", &"target"])
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_effect(
		&"remove_target",
		func(_view: Dictionary) -> Array:
			rr.invalidate_actor(&"target")
			return []
	)
	var op_def := _def(EQActionDefinition.Kind.OPERATION, 0)
	op_def.operation_target_tag = &"counter"
	op_def.effect_name = &"remove_target"
	var op := EQReservation.new(&"attacker", op_def)
	op.target_id = &"target"
	rr.submit(op)
	var resolved := rr.resolve_next()

	t.eq(resolved, op, "operation itself still resolves")
	t.ok(not rr.runtime.registry.is_registered(&"target"), "handler may remove the target")
	t.eq(rr.armed_for(&"target").size(), 0, "removed target never receives a ghost arm")
	t.ok(rr.runtime.scheduler.is_empty(), "removed target receives no expiry or follow-up event")
	t.ok(rr.runtime.faults.is_empty(), "normal target departure creates no schedule fault")


static func _test_reaction_armed(t) -> void:
	var rr = _rr_with([&"hero"])
	var rdef := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	rdef.duration = EQActionDefinition.DURATION_UNLIMITED
	var id := rr.submit(EQReservation.new(&"hero", rdef))
	t.eq(id, -1, "reaction preparation is not scheduled")
	t.ok(rr.runtime.scheduler.is_empty(), "no scheduler event for an armed reaction")
	t.eq(rr.armed_for(&"hero").size(), 1, "reaction preparation is armed")
