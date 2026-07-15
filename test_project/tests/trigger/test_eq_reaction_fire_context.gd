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
	_test_exhausted_count_expiry_roundtrips(t)
	_test_one_scheduled_event_boundary(t)


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
	t.eq(bundle["schema_version"], 6, "reaction context and expiry state ship in schema v6")
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
	historical_bundle.erase("reaction_expiries")
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

	var v5_bundle: Dictionary = bundle.duplicate(true)
	v5_bundle["schema_version"] = 5
	v5_bundle.erase("reaction_expiries")
	var v5_target := _base_runtime()
	v5_target.runtime.register_effect(&"counter", func(_view: Dictionary) -> Array: return [])
	_register_emitter(v5_target, [_damage_view(&"orc", 3)])
	t.ok(
		EQSaveAdapter.load(v5_target.runtime, v5_bundle, {}, v5_target),
		"v5 armed expiry migrates from armed_triggers.expiry_event_id"
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
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "v6 pending FIRE loads")
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


static func _test_exhausted_count_expiry_roundtrips(t) -> void:
	var original := _base_runtime()
	var original_received: Array = []
	original.runtime.register_effect(
		&"counter",
		func(view: Dictionary) -> Array:
			original_received.append(view["reaction_fire_context"].duplicate(true))
			return []
	)
	_register_emitter(original, [_damage_view(&"orc_a", 1), _damage_view(&"orc_b", 2)])
	original.submit(_reaction(&"counter", 1, 5), _condition())
	_submit_emitter(original)
	original.resolve_next()
	t.eq(original.armed_for(&"hero").size(), 0, "two triggers exhaust the armed slot")
	var original_prefix_count := original.runtime.trace().records().size()
	var bundle := EQSaveAdapter.save(original.runtime, original)
	t.eq((bundle["reaction_expiries"] as Array).size(), 1, "stale expiry has an independent row")
	t.eq((bundle["armed_triggers"] as Array).size(), 0, "count-closed slot is not re-armed")
	var expiry_row := (bundle["reaction_expiries"] as Array)[0] as Dictionary
	t.eq(
		int((expiry_row["reservation"] as Dictionary)["status"]),
		EQReservation.Status.RESOLVED,
		"count-closed expiry retains the closed reservation revision"
	)

	var restored := _base_runtime()
	var restored_received: Array = []
	restored.runtime.register_effect(
		&"counter",
		func(view: Dictionary) -> Array:
			restored_received.append(view["reaction_fire_context"].duplicate(true))
			return []
	)
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "v6 exhausted expiry loads")
	t.eq(
		EQSaveAdapter.save(restored.runtime, restored),
		bundle,
		"v6 exhausted save-load-save is value identical"
	)

	for expected_outcome in [
		EQReservationRuntime.ScheduledEventOutcome.RESERVATION,
		EQReservationRuntime.ScheduledEventOutcome.RESERVATION,
		EQReservationRuntime.ScheduledEventOutcome.EXPIRY,
	]:
		var original_step := original.resolve_one_scheduled_event()
		var restored_step := restored.resolve_one_scheduled_event()
		t.eq(restored_step["advanced"], original_step["advanced"], "advance flag continues")
		t.eq(restored_step["event_id"], original_step["event_id"], "event identity continues")
		t.eq(restored_step["event_kind"], original_step["event_kind"], "event kind continues")
		t.eq(restored_step["outcome"], expected_outcome, "one-event outcome is exact")
		var original_res = original_step["reservation"]
		var restored_res = restored_step["reservation"]
		t.ok(original_res is EQReservation and restored_res is EQReservation, "event exposes reservation")
		if original_res is EQReservation and restored_res is EQReservation:
			t.eq(restored_res.to_dict(), original_res.to_dict(), "reservation revision continues")

	t.eq(restored_received, original_received, "both pending FIRE causes continue unchanged")
	var original_suffix := _relative_trace_suffix(original, original_prefix_count)
	var restored_suffix := _relative_trace_suffix(restored, 0)
	t.eq(restored_suffix, original_suffix, "FIRE and stale-expiry trace continuation is identical")
	t.ok(
		'"closed_by":"already_closed"' in original.runtime.trace_jsonl(),
		"count-closed expiry still emits the frozen lightweight trace"
	)

	var v5_orphan := bundle.duplicate(true)
	v5_orphan["schema_version"] = 5
	v5_orphan.erase("reaction_expiries")
	var v5_target := _base_runtime()
	v5_target.runtime.register_effect(&"counter", func(_view: Dictionary) -> Array: return [])
	t.ok(
		not EQSaveAdapter.load(v5_target.runtime, v5_orphan, {}, v5_target),
		"v5 count-closed orphan expiry rejects instead of inventing identity"
	)
	t.eq(
		v5_target.runtime.faults.back()["code"],
		EQError.REACTION_EXPIRY_STATE_INVALID,
		"historical orphan uses the stable expiry-state error"
	)
	t.eq(v5_target.runtime.registry.size(), 2, "verify-before-mutate keeps target registry unchanged")
	t.eq(v5_target.runtime.scheduler.size(), 0, "verify-before-mutate keeps target scheduler unchanged")

	var missing_table := bundle.duplicate(true)
	missing_table.erase("reaction_expiries")
	var missing_target := _base_runtime()
	missing_target.runtime.register_effect(&"counter", func(_view: Dictionary) -> Array: return [])
	t.ok(
		not EQSaveAdapter.load(missing_target.runtime, missing_table, {}, missing_target),
		"v6 requires the reaction_expiries table"
	)
	t.eq(
		missing_target.runtime.faults.back()["code"],
		EQError.REACTION_EXPIRY_STATE_INVALID,
		"missing v6 table uses the stable expiry-state error"
	)

	var wrong_actor := bundle.duplicate(true)
	var expiry_event_id := int(wrong_actor["reaction_expiries"][0]["event_id"])
	for scheduler_entry in wrong_actor["scheduler"]["entries"]:
		if int((scheduler_entry as Dictionary)["event_id"]) == expiry_event_id:
			(scheduler_entry as Dictionary)["actor_id"] = "orc"
	var wrong_actor_target := _base_runtime()
	wrong_actor_target.runtime.register_effect(
		&"counter", func(_view: Dictionary) -> Array: return []
	)
	t.ok(
		not EQSaveAdapter.load(
			wrong_actor_target.runtime, wrong_actor, {}, wrong_actor_target
		),
		"expiry table actor cannot disagree with the scheduler"
	)

	var wrong_status := bundle.duplicate(true)
	wrong_status["reaction_expiries"][0]["reservation"]["status"] = EQReservation.Status.ARMED
	var wrong_status_target := _base_runtime()
	wrong_status_target.runtime.register_effect(
		&"counter", func(_view: Dictionary) -> Array: return []
	)
	t.ok(
		not EQSaveAdapter.load(wrong_status_target.runtime, wrong_status, {}, wrong_status_target),
		"expiry status cannot forge armed membership"
	)

	var duplicate := bundle.duplicate(true)
	duplicate["reaction_expiries"].append(duplicate["reaction_expiries"][0].duplicate(true))
	var duplicate_target := _base_runtime()
	duplicate_target.runtime.register_effect(
		&"counter", func(_view: Dictionary) -> Array: return []
	)
	t.ok(
		not EQSaveAdapter.load(duplicate_target.runtime, duplicate, {}, duplicate_target),
		"duplicate expiry identity rejects before mutation"
	)


static func _test_one_scheduled_event_boundary(t) -> void:
	var rr := _base_runtime()
	var later_calls := [0]
	rr.runtime.register_effect(
		&"later",
		func(_view: Dictionary) -> Array:
			later_calls[0] += 1
			return []
	)
	rr.submit(_reaction(&"", 0, 1), _condition())
	var later_definition := EQActionDefinition.new()
	later_definition.kind = EQActionDefinition.Kind.PREPARED
	later_definition.delay = 2
	later_definition.effect_name = &"later"
	var later_event_id := rr.submit(EQReservation.new(&"orc", later_definition))

	var expiry_step := rr.resolve_one_scheduled_event()
	t.ok(expiry_step["advanced"], "expiry advances one scheduler event")
	t.eq(expiry_step["event_kind"], &"expiry", "expiry is visible as its own boundary")
	t.eq(
		expiry_step["outcome"],
		EQReservationRuntime.ScheduledEventOutcome.EXPIRY,
		"expiry has a stable outcome"
	)
	t.eq(later_calls[0], 0, "the following reservation is not resolved in the same call")
	t.eq((rr.pending()[0] as EQReservation).event_id, later_event_id, "later work remains pending")

	var reservation_step := rr.resolve_one_scheduled_event()
	t.eq(reservation_step["event_id"], later_event_id, "the next call resolves the next event")
	t.eq(
		reservation_step["outcome"],
		EQReservationRuntime.ScheduledEventOutcome.RESERVATION,
		"reservation outcome is distinct"
	)
	t.eq(later_calls[0], 1, "later handler runs exactly once")
	var empty_step := rr.resolve_one_scheduled_event()
	t.ok(not empty_step["advanced"], "empty queue is a non-advancing result")
	t.eq(
		empty_step["outcome"],
		EQReservationRuntime.ScheduledEventOutcome.EMPTY,
		"empty queue has a stable outcome"
	)


static func _relative_trace_suffix(rr: EQReservationRuntime, prefix_count: int) -> Array:
	var records := rr.runtime.trace().records()
	var suffix: Array = []
	for index in range(prefix_count, records.size()):
		suffix.append((records[index] as Dictionary).duplicate(true))
	if suffix.is_empty():
		return suffix
	var first_ordinal := int((suffix[0] as Dictionary).get("i", 0))
	for record in suffix:
		(record as Dictionary)["i"] = int((record as Dictionary).get("i", 0)) - first_ordinal
	return suffix
