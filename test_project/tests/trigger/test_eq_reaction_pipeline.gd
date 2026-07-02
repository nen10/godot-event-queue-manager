extends RefCounted
## EQM-113: fired reactions are SCHEDULED onto the master timeline (§6.2, Q32 —
## never resolved in place), with declared priority, round-numbered traces, and
## event-ized duration expiry (§6.3, Q40 — closed_by duration / reaction_count /
## already_closed).

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")


static func run(t) -> void:
	_test_fired_reaction_is_scheduled(t)
	_test_reaction_count_close(t)
	_test_expiry_event_closes_armed(t)
	_test_expiry_already_closed(t)


static func _rr(actors: Array) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for a in actors:
		rr.runtime.register_actor(a)
	return rr


static func _attack(target: StringName) -> EQReservation:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.IMMEDIATE
	d.tags = [&"damage"]
	var r := EQReservation.new(&"orc", d)
	r.target_id = target
	return r


static func _counter_condition(owner: StringName) -> EQCondition:
	var c := EQCondition.new()
	c.match_target = owner
	c.require_tags = [&"damage"]
	return c


static func _reaction(owner: StringName, rumination: int = 0, duration: int = EQActionDefinition.DURATION_UNLIMITED) -> EQReservation:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	d.duration = duration
	d.rumination = rumination
	d.priority = 5
	return EQReservation.new(owner, d)


static func _test_fired_reaction_is_scheduled(t) -> void:
	var rr := _rr([&"hero", &"orc"])
	rr.submit(_reaction(&"hero"), _counter_condition(&"hero"))
	rr.submit(_attack(&"hero"))

	var attack = rr.resolve_next()
	t.eq(attack.actor_id, &"orc", "the attack resolves first")
	t.eq(rr.runtime.scheduler.size(), 1, "the fired counter was SCHEDULED, not resolved in place (Q32)")
	var entry = rr.runtime.scheduler.peek_next()
	t.eq(entry.due_tick, 0, "fired reaction is due at the current tick")
	t.eq(entry.priority, 5, "fired reaction carries its declared priority")
	t.ok('"kind":"reaction_fired"' in rr.runtime.trace_jsonl() and '"round":1' in rr.runtime.trace_jsonl(), "firing is traced with its round number")

	var counter = rr.resolve_next()
	t.eq(counter.actor_id, &"hero", "the counter resolves through the normal pipeline on the next pop")
	t.eq(counter.status, EQReservation.Status.RESOLVED, "scheduled reaction resolution completes")


static func _test_reaction_count_close(t) -> void:
	var rr := _rr([&"hero", &"orc"])
	rr.submit(_reaction(&"hero", 1), _counter_condition(&"hero"))  # fires twice total

	rr.submit(_attack(&"hero"))
	rr.resolve_next()  # attack -> fire 1 (re-armed)
	rr.resolve_next()  # counter 1 resolves
	t.eq(rr.armed_for(&"hero").size(), 1, "rumination 1 re-arms after the first fire")

	rr.submit(_attack(&"hero"))
	rr.resolve_next()  # attack -> fire 2 (consumed)
	t.eq(rr.armed_for(&"hero").size(), 0, "count exhaustion closes the armed slot")
	t.ok('"closed_by":"reaction_count"' in rr.runtime.trace_jsonl(), "count exhaustion is traced (closed_by: reaction_count)")
	var final = rr.resolve_next()
	t.eq(final.actor_id, &"hero", "the final fire still resolves (the slot closed, not the fired action)")


static func _test_expiry_event_closes_armed(t) -> void:
	var rr := _rr([&"hero"])
	rr.runtime.register_effect(&"guard_down", func(_v) -> Array:
		var rec := EQEffectRecord.new()
		rec.kind = &"guard_down"
		return [rec])
	var res := _reaction(&"hero", 0, 5)
	res.definition.expiry_effect_name = &"guard_down"
	rr.submit(res, _counter_condition(&"hero"))
	t.eq(rr.runtime.scheduler.size(), 1, "arming with a duration schedules its expiry EVENT (§6.3)")

	t.eq(rr.resolve_next(), null, "the expiry event is consumed internally (not a reservation resolution)")
	t.eq(res.status, EQReservation.Status.INVALIDATED, "expiry closes the armed reaction")
	t.eq(rr.armed_for(&"hero").size(), 0, "expired reaction is disarmed")
	t.eq(rr.runtime.scheduler.current_tick, 5, "expiry landed on the timeline at armed_at + duration")
	t.ok('"closed_by":"duration"' in rr.runtime.trace_jsonl(), "expiry is traced (closed_by: duration) — never silent (Q06 是正)")
	t.eq(rr.last_drained.size(), 1, "the optional on-expiry effect ran through the pipeline")
	t.eq(rr.last_drained[0].kind, &"guard_down", "expiry effect record reached the chunk drain")


static func _test_expiry_already_closed(t) -> void:
	var rr := _rr([&"hero", &"orc"])
	rr.submit(_reaction(&"hero", 0, 5), _counter_condition(&"hero"))
	rr.submit(_attack(&"hero"))
	rr.resolve_next()  # attack -> fires and consumes the one-shot reaction
	rr.resolve_next()  # the fired counter resolves
	t.eq(rr.armed_for(&"hero").size(), 0, "one-shot reaction consumed before its deadline")

	t.eq(rr.resolve_next(), null, "expiry event pops later and is consumed internally")
	t.ok('"closed_by":"already_closed"' in rr.runtime.trace_jsonl(), "a stale expiry leaves the lightweight already_closed record")
