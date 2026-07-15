extends RefCounted
## EQM-132: one reaction FIRE is an independent scheduled occurrence carrying
## an immutable, versioned trigger cause through callback, trace, and save/load.

const EQReservationRuntime := preload(
	"res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd"
)
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQEffectCommitResult := preload(
	"res://addons/event_queue_manager/runtime/eq_effect_commit_result.gd"
)
const EQSaveAdapter := preload("res://addons/event_queue_manager/runtime/eq_save_adapter.gd")


static func run(t) -> void:
	_test_two_fires_are_independent_occurrences(t)
	_test_intermediate_fire_keeps_arm_until_expiry(t)
	_test_pending_fire_context_roundtrips(t)


static func _reaction(
	effect_name: StringName, rumination: int = 1, duration: int = 6
) -> EQReservation:
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	definition.duration = duration
	definition.rumination = rumination
	definition.effect_name = effect_name
	definition.tags = [&"counter"]
	return EQReservation.new(&"hero", definition)


static func _condition(mutate: bool = false) -> EQCondition:
	var condition := EQCondition.new()
	condition.match_target = &"hero"
	condition.require_tags = [&"damage"]
	if mutate:
		condition.custom_predicate = func(view: Dictionary) -> bool:
			view["source"] = &"condition_mutated"
			return true
	return condition


static func _damage_view(source: StringName, q: int) -> Dictionary:
	return {
		"kind": &"effect_fact",
		"source": source,
		"target": &"hero",
		"cell": {"q": q, "r": -q},
		"tags": [&"damage", &"hp_changed"],
		"actual_delta": -4,
	}


static func _register_emitter(rr: EQReservationRuntime, views: Array) -> void:
	rr.runtime.register_effect_commit(
		&"emit_damage",
		func(_view: Dictionary): return EQEffectCommitResult.make_success([], views)
	)


static func _submit_emitter(rr: EQReservationRuntime) -> int:
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.IMMEDIATE
	definition.effect_name = &"emit_damage"
	var reservation := EQReservation.new(&"orc", definition)
	return rr.submit(reservation)


static func _base_runtime() -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")
	return rr


static func _test_two_fires_are_independent_occurrences(t) -> void:
	var rr := _base_runtime()
	var received: Array = []
	rr.runtime.register_effect(
		&"counter",
		func(view: Dictionary) -> Array:
			received.append(view["reaction_fire_context"].duplicate(true))
			# A consumer mutating its callback copy cannot affect a later FIRE or trace.
			view["reaction_fire_context"]["trigger"]["source"] = "handler_mutated"
			return []
	)
	_register_emitter(rr, [_damage_view(&"orc_a", 1), _damage_view(&"orc_b", 2)])
	var armed := _reaction(&"counter", 1)
	rr.submit(armed, _condition(true))
	_submit_emitter(rr)
	rr.resolve_next()

	var pending := rr.pending()
	t.eq(pending.size(), 2, "two matching committed views schedule two FIRE occurrences")
	t.ok(pending[0] != pending[1], "each FIRE has its own reservation instance")
	t.ok(pending[0] != armed and pending[1] != armed, "neither FIRE aliases the armed slot")
	t.eq(rr.armed_for(&"hero").size(), 0, "the second FIRE exhausts max_fires=2")

	var event_ids: Array[int] = []
	for reservation in pending:
		event_ids.append((reservation as EQReservation).event_id)
	event_ids.sort()
	var first := rr.reaction_fire_context_for_event(event_ids[0])
	var second := rr.reaction_fire_context_for_event(event_ids[1])
	t.eq(first["fire_index"], 1, "first FIRE index is one-based")
	t.eq(second["fire_index"], 2, "second FIRE index is exact")
	t.eq(first["fire_event_id"], event_ids[0], "context binds its scheduled event id")
	t.eq(second["fire_event_id"], event_ids[1], "second context binds its event id")
	t.eq(first["trigger"]["view_index"], 0, "first cause retains producer view index")
	t.eq(second["trigger"]["view_index"], 1, "second cause retains producer view index")
	t.eq(first["trigger"]["source"], "orc_a", "condition mutation cannot rewrite cause")
	t.eq(second["trigger"]["source"], "orc_b", "each cause keeps its own source")
	first["trigger"]["source"] = "inspection_mutated"
	t.eq(
		rr.reaction_fire_context_for_event(event_ids[0])["trigger"]["source"],
		"orc_a",
		"inspection returns a deep copy"
	)

	rr.resolve_next()
	rr.resolve_next()
	t.eq(received.size(), 2, "both FIRE effects resolve")
	t.eq(received[0]["trigger"]["source"], "orc_a", "first handler receives first cause")
	t.eq(received[1]["trigger"]["source"], "orc_b", "handler mutation does not leak")
	var count_closures := 0
	for record in rr.runtime.trace().records():
		if record.get("kind", "") == "event_invalidated" and record.get("closed_by", "") == "reaction_count":
			count_closures += 1
	t.eq(count_closures, 1, "count exhaustion is traced exactly once")


static func _test_intermediate_fire_keeps_arm_until_expiry(t) -> void:
	var rr := _base_runtime()
	rr.runtime.register_effect(&"counter", func(_view: Dictionary) -> Array: return [])
	_register_emitter(rr, [_damage_view(&"orc", 0)])
	var armed := _reaction(&"counter", 1, 3)
	rr.submit(armed, _condition())
	_submit_emitter(rr)
	rr.resolve_next()
	t.eq(armed.status, EQReservation.Status.ARMED, "scheduled FIRE does not change armed status")
	t.eq(rr.armed_for(&"hero").size(), 1, "one use remains armed")
	rr.resolve_next()
	t.eq(armed.status, EQReservation.Status.ARMED, "resolving FIRE still leaves arm intact")
	rr.resolve_next()  # consumes the expiry event internally, then reaches empty
	t.eq(armed.status, EQReservation.Status.INVALIDATED, "duration closes the true armed slot")
	t.eq(rr.armed_for(&"hero").size(), 0, "expiry removes the arm membership")
	var duration_closures := 0
	for record in rr.runtime.trace().records():
		if record.get("kind", "") == "event_invalidated" and record.get("closed_by", "") == "duration":
			duration_closures += 1
	t.eq(duration_closures, 1, "expiry closure remains observable")


static func _test_pending_fire_context_roundtrips(t) -> void:
	var original := _base_runtime()
	var original_received: Array = []
	original.runtime.register_effect(
		&"counter",
		func(view: Dictionary) -> Array:
			original_received.append(view["reaction_fire_context"].duplicate(true))
			return []
	)
	_register_emitter(original, [_damage_view(&"orc", 3)])
	original.submit(_reaction(&"counter", 1, 5), _condition())
	_submit_emitter(original)
	original.resolve_next()
	var bundle := EQSaveAdapter.save(original.runtime, original)
	t.eq(bundle["schema_version"], 5, "reaction context ships in save schema v5")
	var saved_row: Dictionary = bundle["scheduled_reservations"][0]
	t.ok(not saved_row["reaction_fire_context"].is_empty(), "pending FIRE saves its cause")

	var missing_bundle: Dictionary = bundle.duplicate(true)
	missing_bundle["scheduled_reservations"][0].erase("reaction_fire_context")
	var missing_target := EQReservationRuntime.new()
	missing_target.runtime.emit_engine_diagnostics = false
	missing_target.runtime.register_effect(&"counter", func(_view: Dictionary) -> Array: return [])
	_register_emitter(missing_target, [_damage_view(&"orc", 3)])
	t.ok(
		not EQSaveAdapter.load(missing_target.runtime, missing_bundle, {}, missing_target),
		"v5 rejects a pending FIRE whose context field is absent"
	)

	var mismatch_bundle: Dictionary = bundle.duplicate(true)
	mismatch_bundle["scheduled_reservations"][0]["reaction_fire_context"]["fire_event_id"] += 1
	var mismatch_target := EQReservationRuntime.new()
	mismatch_target.runtime.emit_engine_diagnostics = false
	mismatch_target.runtime.register_effect(
		&"counter", func(_view: Dictionary) -> Array: return []
	)
	_register_emitter(mismatch_target, [_damage_view(&"orc", 3)])
	t.ok(
		not EQSaveAdapter.load(mismatch_target.runtime, mismatch_bundle, {}, mismatch_target),
		"v5 rejects context bound to another FIRE event id"
	)

	var historical_bundle: Dictionary = bundle.duplicate(true)
	historical_bundle["schema_version"] = 4
	historical_bundle["scheduled_reservations"][0].erase("reaction_fire_context")
	var historical_target := EQReservationRuntime.new()
	historical_target.runtime.emit_engine_diagnostics = false
	historical_target.runtime.register_effect(
		&"counter", func(_view: Dictionary) -> Array: return []
	)
	_register_emitter(historical_target, [_damage_view(&"orc", 3)])
	t.ok(
		not EQSaveAdapter.load(
			historical_target.runtime, historical_bundle, {}, historical_target
		),
		"historical pending FIRE is rejected instead of inventing its cause"
	)

	var restored := EQReservationRuntime.new()
	restored.runtime.emit_engine_diagnostics = false
	var restored_received: Array = []
	restored.runtime.register_effect(
		&"counter",
		func(view: Dictionary) -> Array:
			restored_received.append(view["reaction_fire_context"].duplicate(true))
			return []
	)
	_register_emitter(restored, [_damage_view(&"orc", 3)])
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "v5 pending FIRE loads")
	t.eq(restored.armed_for(&"hero").size(), 1, "remaining arm also roundtrips")
	t.eq(EQSaveAdapter.save(restored.runtime, restored), bundle, "save-load-save is value identical")

	original.resolve_next()
	restored.resolve_next()
	t.eq(restored_received, original_received, "restored handler receives the identical cause")
	var original_trace: Dictionary = original.runtime.trace().records().back().duplicate(true)
	var restored_trace: Dictionary = restored.runtime.trace().records().back().duplicate(true)
	original_trace.erase("i")
	restored_trace.erase("i")
	t.eq(restored_trace, original_trace, "future reaction trace is identical after normalization")
