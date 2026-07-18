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
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQConditionSpec := preload(
	"res://addons/event_queue_manager/resources/eq_condition_spec.gd"
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
	_test_reaction_condition_wrong_type_fails_closed_in_dev(t)
	_test_reaction_condition_wrong_type_fails_closed_in_shipped(t)


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


static func _wrong_reaction_condition() -> EQConditionSpec:
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.NAMED_PREDICATE
	spec.predicate_name = &"not_a_trigger_matcher"
	return spec


static func _reaction_reservation(
	duration: int = EQActionDefinition.DURATION_UNLIMITED
) -> EQReservation:
	var definition := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	definition.duration = duration
	definition.meta_level = 7
	return EQReservation.new(&"hero", definition)


static func _assert_wrong_condition_has_no_issued_state(t, rr, reservation: EQReservation) -> void:
	t.eq(reservation.status, EQReservation.Status.PENDING, "rejected reaction stays unissued")
	t.eq(reservation.event_id, -1, "rejected reaction receives no event id")
	t.eq(reservation.effect_commit_result_version, -1, "rejected reaction binds no effect mode")
	t.eq(reservation.expiry_effect_commit_result_version, -1, "rejected reaction binds no expiry mode")
	t.eq(reservation._issued_meta_level, null, "rejected reaction samples no issued meta")
	t.eq(rr.engine.armed_count(), 0, "rejected reaction creates no ghost arm")
	t.ok(rr.runtime.scheduler.is_empty(), "rejected reaction creates no scheduler or expiry work")


static func _assert_reaction_rejection_trace(t, rr, label: String) -> void:
	var records: Array = rr.runtime.trace().records()
	t.eq(records.size(), 1, "%s records exactly one pre-submit trace" % label)
	if records.size() != 1:
		return
	t.eq(
		records[0],
		{
			"i": 0,
			"kind": "reservation_rejected",
			"actor": "hero",
			"code": String(EQError.REACTION_CONDITION_TYPE_INVALID),
			"reason": "wrong_type",
		},
		"%s rejection trace has the authoritative record shape" % label
	)


static func _test_reaction_condition_wrong_type_fails_closed_in_dev(t) -> void:
	var rr = _rr_with([&"hero"])
	rr.runtime.emit_engine_diagnostics = false
	var reservation := _reaction_reservation(5)
	t.eq(rr.submit(reservation, _wrong_reaction_condition()), -1, "wrong trigger type is rejected")
	_assert_wrong_condition_has_no_issued_state(t, rr, reservation)
	t.ok(rr.runtime.halted, "dev mode halts on the reaction-condition contract violation")
	t.eq(
		rr.runtime.faults.back()["code"],
		EQError.REACTION_CONDITION_TYPE_INVALID,
		"wrong trigger type uses the stable reaction-condition code"
	)
	t.eq(
		rr.runtime.faults.back()["recoverability"],
		EQError.Recoverability.CONTRACT_VIOLATION,
		"wrong trigger type is a contract violation"
	)
	_assert_reaction_rejection_trace(t, rr, "dev")


static func _test_reaction_condition_wrong_type_fails_closed_in_shipped(t) -> void:
	var rr = _rr_with([&"hero", &"enemy"])
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.set_mode(rr.runtime.Mode.SHIPPED)
	var rejected := _reaction_reservation(5)
	t.eq(rr.submit(rejected, _wrong_reaction_condition()), -1, "shipped mode rejects wrong trigger type")
	_assert_wrong_condition_has_no_issued_state(t, rr, rejected)
	t.ok(not rr.runtime.halted, "shipped rejection does not halt the runtime")
	t.eq(rr.runtime.faults.back()["code"], EQError.REACTION_CONDITION_TYPE_INVALID, "shipped records the same stable fault")
	_assert_reaction_rejection_trace(t, rr, "shipped")

	var valid := _reaction_reservation()
	var condition := EQCondition.new()
	condition.match_target = &"hero"
	t.eq(rr.submit(valid, condition), -1, "a valid reaction remains the unscheduled arm path")
	t.eq(valid.status, EQReservation.Status.ARMED, "shipped runtime accepts a later valid reaction")
	t.eq(rr.engine.armed_count(), 1, "later valid reaction is indexed once")
	var incoming_definition := _def(EQActionDefinition.Kind.IMMEDIATE)
	incoming_definition.tags = [&"damage"]
	var incoming := EQReservation.new(&"enemy", incoming_definition)
	incoming.target_id = &"hero"
	t.ok(rr.submit(incoming) > 0, "later incoming event enters the reservation pipeline")
	t.eq(rr.resolve_next(), incoming, "later incoming event resolves after shipped rejection")
	t.eq(rr.engine.armed_count(), 0, "valid one-shot reaction is consumed by the pipeline sweep")
	var fired_records: Array = rr.runtime.trace().records().filter(
		func(record): return record.get("kind", "") == "reaction_fired"
	)
	t.eq(fired_records.size(), 1, "pipeline sweep schedules exactly one valid reaction FIRE")
	t.eq(rr.pending().size(), 1, "scheduled reaction FIRE remains pending until its own pop")
	var fired := rr.resolve_next()
	t.ok(fired != null, "scheduled reaction FIRE resolves through the pipeline")
	if fired != null:
		t.eq(fired.actor_id, &"hero", "resolved FIRE belongs to the valid reaction owner")
		t.eq(fired.status, EQReservation.Status.RESOLVED, "resolved FIRE completes normally")
	t.eq(
		rr.runtime.trace().records().filter(
			func(record): return record.get("kind", "") == "reaction_fire_resolved"
		).size(),
		1,
		"later valid reaction records one resolved FIRE after shipped rejection"
	)
