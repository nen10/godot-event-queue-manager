extends RefCounted
## EQM-113: the §6.1 resolution pipeline — declared effect linkage, chunk/save
## boundary, condition-gated push at the detection tick (Q27), lazy + sweep
## (numeric-eager) invalidation, invalidation-wins, and the invalidate_actor
## normal departure path (Q39, mode-neutral).

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQNodeBridge := preload("res://addons/event_queue_manager/runtime/eq_node_bridge.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_effect_linkage(t)
	_test_effectless_and_unregistered(t)
	_test_condition_gated_pushes_at_detection_tick(t)
	_test_lazy_invalidation(t)
	_test_sweep_numeric_invalidation(t)
	_test_invalidation_wins(t)
	_test_invalidate_actor(t)
	_test_bridge_routes_departure(t)


static func _rr(actors: Array) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for a in actors:
		rr.runtime.register_actor(a)
	return rr


static func _def(kind: int, delay: int = 0) -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = kind
	d.delay = delay
	return d


static func _record(kind: StringName) -> EQEffectRecord:
	var r := EQEffectRecord.new()
	r.kind = kind
	return r


static func _line_spec(line: StringName, threshold: int, cmp: int = EQConditionSpec.Comparison.GE) -> EQConditionSpec:
	var s := EQConditionSpec.new()
	s.type = EQConditionSpec.Type.LINE_THRESHOLD
	s.line_id = line
	s.threshold = threshold
	s.comparison = cmp
	return s


static func _test_effect_linkage(t) -> void:
	var rr := _rr([&"hero"])
	rr.runtime.register_effect(&"strike", func(view: Dictionary) -> Array:
		return [_record(StringName("hit_%s" % view["source"]))])
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"strike"
	rr.submit(EQReservation.new(&"hero", d))
	var res = rr.resolve_next()
	t.eq(res.status, EQReservation.Status.RESOLVED, "declared effect resolution succeeds")
	t.eq(rr.last_drained.size(), 1, "effect records flow through the chunk into last_drained")
	t.eq(rr.last_drained[0].kind, &"hit_hero", "handler received the serializable event view")
	t.ok(rr.chunk.is_save_allowed(), "chunk is empty after resolve (save boundary, §10)")


static func _test_effectless_and_unregistered(t) -> void:
	var rr := _rr([&"hero"])
	rr.submit(EQReservation.new(&"hero", _def(EQActionDefinition.Kind.IMMEDIATE)))
	var res = rr.resolve_next()
	t.eq(res.status, EQReservation.Status.RESOLVED, "empty effect_name = explicitly effect-less resolution (legal)")
	t.eq(rr.last_drained.size(), 0, "effect-less resolution adds nothing to the chunk")

	var shipped := _rr([&"hero"])
	shipped.runtime.set_mode(EQRuntime.Mode.SHIPPED)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"missing"
	shipped.submit(EQReservation.new(&"hero", d))
	var got = shipped.resolve_next()
	t.ok(got != null, "shipped mode skips the missing effect and continues (fail-safe)")
	t.eq(shipped.runtime.faults.back()["code"], EQError.EFFECT_UNREGISTERED, "set-but-unregistered is a stable error, never a silent skip")

	var dev := _rr([&"hero"])
	dev.submit(EQReservation.new(&"hero", d))
	dev.resolve_next()
	t.ok(dev.runtime.halted, "dev mode halts on a declared-but-unregistered effect (fail-fast)")


static func _test_condition_gated_pushes_at_detection_tick(t) -> void:
	var rr := _rr([&"hero"])
	rr.lines.issue(&"ct.hero", 0, 5)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.solve_conditions = [_line_spec(&"ct.hero", 100)]
	var res := EQReservation.new(&"hero", d)
	t.eq(rr.submit(res), -1, "condition-gated reservation is not scheduled at submit")
	t.eq(rr.pending_conditional().size(), 1, "it waits in the conditional set")

	for _i in 19:
		rr.step_tick()
	t.ok(rr.runtime.scheduler.is_empty(), "not pushed while the level is below threshold (ct=95)")
	rr.step_tick()  # tick 20 -> ct = 100
	t.eq(rr.runtime.scheduler.peek_next().due_tick, 20, "pushed with due_tick = the detection tick (Q27)")
	var got = rr.resolve_next()
	t.eq(got, res, "condition-gated reservation resolves through the normal pipeline")
	t.eq(rr.runtime.scheduler.current_tick, 20, "resolved at the detection tick")


static func _test_lazy_invalidation(t) -> void:
	var rr := _rr([&"hero"])
	rr.lines.issue(&"hp.hero", 10, 0)
	var d := _def(EQActionDefinition.Kind.PREPARED, 3)
	var owner_dead := _line_spec(&"hp.hero", 0, EQConditionSpec.Comparison.LE)
	owner_dead.condition_id = &"owner_dead"
	d.invalidation_conditions = [owner_dead]
	var res := EQReservation.new(&"hero", d)
	rr.submit(res)
	rr.lines.advance(&"hp.hero", -10)  # dies before the delay elapses
	t.eq(rr.resolve_next(), null, "an invalidated event never resolves (lazy check at pop)")
	t.eq(res.status, EQReservation.Status.INVALIDATED, "reservation is invalidated, not resolved")
	t.ok('"closed_by":"owner_dead"' in rr.runtime.trace_jsonl(), "trace explains the drop via closed_by (§11)")


static func _test_sweep_numeric_invalidation(t) -> void:
	var rr := _rr([&"hero", &"orc"])
	rr.lines.issue(&"hp.orc", 10, 0)
	# orc's prepared action drops the moment its hp reaches 0 — evaluated at the
	# sweep after hero's resolution ("looks eager, evaluated at a defined point", §5.3)
	var od := _def(EQActionDefinition.Kind.PREPARED, 5)
	var dead := _line_spec(&"hp.orc", 0, EQConditionSpec.Comparison.LE)
	dead.condition_id = &"owner_dead"
	od.invalidation_conditions = [dead]
	var orc_action := EQReservation.new(&"orc", od)
	rr.submit(orc_action)

	rr.runtime.register_effect(&"slay", func(_v) -> Array:
		rr.lines.advance(&"hp.orc", -10)
		return [_record(&"slay")])
	var hd := _def(EQActionDefinition.Kind.IMMEDIATE)
	hd.effect_name = &"slay"
	rr.submit(EQReservation.new(&"hero", hd))

	var got = rr.resolve_next()
	t.eq(got.actor_id, &"hero", "hero's immediate action resolves first")
	t.eq(orc_action.status, EQReservation.Status.INVALIDATED, "the sweep re-check cancelled the dead orc's pending action")
	t.ok(rr.runtime.scheduler.is_empty(), "cancelled event left the timeline")


static func _test_invalidation_wins(t) -> void:
	var rr := _rr([&"hero"])
	rr.lines.issue(&"charge", 0, 1)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.solve_conditions = [_line_spec(&"charge", 10)]
	var boom := _line_spec(&"charge", 10)
	boom.condition_id = &"overload"
	d.invalidation_conditions = [boom]
	var res := EQReservation.new(&"hero", d)
	rr.submit(res)
	for _i in 10:
		rr.step_tick()
	t.eq(res.status, EQReservation.Status.INVALIDATED, "solve and invalidation holding together invalidates (invalidation-wins, Q28)")
	t.ok(rr.runtime.scheduler.is_empty(), "nothing was pushed for the losing solve")
	t.ok('"closed_by":"overload"' in rr.runtime.trace_jsonl(), "closed_by names the winning invalidation term")


static func _departure_setup() -> EQReservationRuntime:
	var rr := _rr([&"hero", &"orc"])
	rr.submit(EQReservation.new(&"hero", _def(EQActionDefinition.Kind.PREPARED, 5)))
	var reaction := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction.duration = 9
	rr.submit(EQReservation.new(&"hero", reaction))
	var gated := _def(EQActionDefinition.Kind.IMMEDIATE)
	gated.solve_conditions = [_line_spec(&"never", 1)]
	rr.lines.issue(&"never", 0, 0)
	rr.submit(EQReservation.new(&"hero", gated))
	rr.submit(EQReservation.new(&"orc", _def(EQActionDefinition.Kind.PREPARED, 2)))
	return rr


static func _test_invalidate_actor(t) -> void:
	var dev := _departure_setup()
	var cancelled := dev.invalidate_actor(&"hero")
	t.eq(cancelled, 2, "pending scheduled events cancelled (prepared + reaction expiry)")
	t.eq(dev.armed_for(&"hero").size(), 0, "armed reactions disarmed")
	t.eq(dev.pending_conditional().size(), 0, "conditional reservations dropped")
	t.ok(not dev.runtime.registry.is_registered(&"hero"), "actor unregistered")
	t.ok(not dev.runtime.halted, "departure is NORMAL gameplay: dev mode does not halt (Q39, Q05 是正)")
	t.ok(dev.runtime.faults.is_empty(), "no fault recorded on the normal path")
	t.ok('"closed_by":"actor_removed"' in dev.runtime.trace_jsonl(), "trace explains via closed_by: actor_removed")
	var got = dev.resolve_next()
	t.eq(got.actor_id, &"orc", "other actors' events survive and resolve")

	# mode neutrality: shipped produces the identical trace for identical input
	var shipped := _departure_setup()
	shipped.runtime.set_mode(EQRuntime.Mode.SHIPPED)
	shipped.invalidate_actor(&"hero")
	shipped.resolve_next()
	t.eq(shipped.runtime.trace_jsonl(), dev.runtime.trace_jsonl(), "dev and shipped traces are byte-identical (mode neutrality)")


static func _test_bridge_routes_departure(t) -> void:
	var m := EQManager.new()
	m.register_actor(&"hero")
	m.runtime().schedule(&"hero", 3, 0, &"turn")
	var bridge := EQNodeBridge.new(m)
	bridge.on_actor_freed(&"hero")
	t.ok(not m.runtime().registry.is_registered(&"hero"), "bridge routes a freed actor through invalidate_actor")
	t.ok('"closed_by":"actor_removed"' in m.runtime().trace_jsonl(), "bridge departure leaves the closed_by trace")
	t.ok(m.runtime().scheduler.is_empty(), "freed actor's pending events were cancelled, not left to rot")
	bridge.free()
	m.free()
