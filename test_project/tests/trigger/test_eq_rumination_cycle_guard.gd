extends RefCounted
## EQM-062: rumination (reservation reschedule + reaction re-arm) and the trigger
## cycle guard (a runaway cascade is bounded and reported, never an infinite loop).

const EQReservationRuntime := preload(
	"res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd"
)
const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_reservation_rumination(t)
	_test_removed_actor_cancels_only_future_rumination(t)
	_test_reaction_rumination(t)
	_test_cycle_guard(t)


static func _test_reservation_rumination(t) -> void:
	var rr := EQReservationRuntime.new()
	rr.runtime.register_actor(&"hero")
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.PREPARED
	def.delay = 2
	def.rumination = 2  # resolves, then reschedules twice
	var res := EQReservation.new(&"hero", def)
	rr.submit(res)
	var resolves := 0
	for _i in 6:
		var got = rr.resolve_next()
		if got == null:
			break
		resolves += 1
	t.eq(resolves, 3, "rumination 2 -> resolves 3 times (initial + 2 reschedules)")
	t.eq(res.remaining_ruminations, 0, "rumination count decremented to 0")
	t.ok(rr.runtime.scheduler.is_empty(), "no further reschedule once ruminations are exhausted")


static func _test_removed_actor_cancels_only_future_rumination(t) -> void:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"origin")
	rr.runtime.register_actor(&"witness")
	rr.submit(_reaction(&"witness", 0), _cond(&"witness"))

	rr.runtime.register_effect(
		&"depart",
		func(_view: Dictionary) -> Array:
			rr.invalidate_actor(&"origin")
			var record := EQEffectRecord.new()
			record.kind = &"depart"
			return [record]
	)
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.IMMEDIATE
	definition.effect_name = &"depart"
	definition.rumination = 2
	definition.tags = [&"damage"]
	var reservation := EQReservation.new(&"origin", definition)
	reservation.target_id = &"witness"
	rr.submit(reservation)
	rr.resolve_next()

	t.ok(not rr.runtime.registry.is_registered(&"origin"), "handler may remove its source normally")
	t.eq(rr.last_drained.size(), 1, "the current successful effect remains published")
	t.eq(
		reservation.remaining_ruminations, 0, "future rumination is cancelled, not ghost-submitted"
	)
	t.eq(rr.runtime.scheduler.size(), 1, "the current outer sweep still schedules other actors")
	t.eq(rr.runtime.scheduler.peek_next().actor_id, &"witness", "only the witness reaction remains")
	t.ok(rr.runtime.faults.is_empty(), "normal actor departure creates no schedule fault")


static func _reaction(owner: StringName, rumination: int) -> EQReservation:
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	def.duration = EQActionDefinition.DURATION_UNLIMITED
	def.rumination = rumination
	var r := EQReservation.new(owner, def)
	return r


static func _dmg(target: StringName) -> Dictionary:
	return {"kind": &"hit", "source": &"orc", "target": target, "tags": [&"damage"]}


static func _cond(owner: StringName) -> EQCondition:
	var c := EQCondition.new()
	c.match_target = owner
	c.require_tags = [&"damage"]
	return c


static func _test_reaction_rumination(t) -> void:
	var eng := EQTriggerEngine.new()
	eng.arm(_reaction(&"hero", 2), _cond(&"hero"), 0)  # fires 3 times (re-arm twice)
	var fires := 0
	for tick in range(1, 6):
		if eng.on_event_resolved(_dmg(&"hero"), tick).size() > 0:
			fires += 1
	t.eq(fires, 3, "reaction rumination 2 -> fires 3 times (re-armed twice)")
	t.eq(eng.armed_count(), 0, "consumed after ruminations exhausted")

	# rumination 0 stays one-shot (EQM-061 compatibility)
	var eng2 := EQTriggerEngine.new()
	eng2.arm(_reaction(&"hero", 0), _cond(&"hero"), 0)
	t.eq(eng2.on_event_resolved(_dmg(&"hero"), 1).size(), 1, "rumination 0 fires once")
	t.eq(eng2.on_event_resolved(_dmg(&"hero"), 2).size(), 0, "rumination 0 is one-shot")


static func _test_cycle_guard(t) -> void:
	# EQM-113 (Q32): the in-place fire_cascade was removed — fired reactions are
	# SCHEDULED, and the runaway bound is the pipeline's same-tick round guard.
	# A self-sustaining reaction (its own resolution re-matches its condition)
	# must be truncated with a TRIGGER_CHAIN_LIMIT fault, never an infinite loop.
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.set_mode(rr.runtime.Mode.SHIPPED)  # observe truncation (dev halts)
	rr.max_cascade_rounds = 4
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")

	var echo := _reaction(&"hero", 1000000)
	echo.definition.tags = [&"damage"]  # its own resolution re-matches ...
	echo.target_id = &"hero"  # ... the condition below (runaway)
	rr.submit(echo, _cond(&"hero"))

	var trigger_def := EQActionDefinition.new()
	trigger_def.kind = EQActionDefinition.Kind.IMMEDIATE
	trigger_def.tags = [&"damage"]
	var first := EQReservation.new(&"orc", trigger_def)
	first.target_id = &"hero"
	rr.submit(first)

	var resolutions := 0
	for _i in 32:
		if rr.resolve_next() == null:
			break
		resolutions += 1
	t.ok(
		resolutions <= rr.max_cascade_rounds + 2,
		"cascade bounded by max_cascade_rounds (resolved=%d)" % resolutions
	)
	t.ok(not rr.runtime.faults.is_empty(), "cycle guard recorded a fault")
	t.eq(
		rr.runtime.faults.back()["code"],
		EQError.TRIGGER_CHAIN_LIMIT,
		"fault code is trigger.chain_limit"
	)
	t.eq(
		rr.runtime.faults.back()["recoverability"],
		EQError.Recoverability.BUDGET_EXCEEDED,
		"chain limit is BUDGET_EXCEEDED"
	)
	t.ok(
		rr.runtime.scheduler.is_empty(),
		"truncation stops scheduling new rounds (shipped fail-safe, no crash)"
	)

	# a terminating cascade (one-shot reaction, non-matching resolution) records no fault
	var rr2 := EQReservationRuntime.new()
	rr2.runtime.emit_engine_diagnostics = false
	rr2.runtime.register_actor(&"hero")
	rr2.runtime.register_actor(&"orc")
	rr2.submit(_reaction(&"hero", 0), _cond(&"hero"))
	var atk := EQReservation.new(&"orc", trigger_def)
	atk.target_id = &"hero"
	rr2.submit(atk)
	for _i in 8:
		if rr2.resolve_next() == null:
			break
	t.eq(rr2.runtime.faults.size(), 0, "a terminating cascade records no fault")
