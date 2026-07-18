extends RefCounted
## EQM-141: event matching is a non-mutating preview. Definition conditions
## gate FIRE before rumination/counter commit and persist as arm-bound state.

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
const EQTriggerEngine := preload(
	"res://addons/event_queue_manager/runtime/eq_trigger_engine.gd"
)
const EQSaveAdapter := preload(
	"res://addons/event_queue_manager/runtime/eq_save_adapter.gd"
)
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_engine_preview_is_non_mutating_and_single_commit(t)
	_test_preview_filters_expiry_without_mutation(t)
	_test_named_solve_waits_then_fires_with_composite_view(t)
	_test_invalidation_wins_before_commit(t)
	_test_counter_binds_once_and_closes_after_accepted_fires(t)
	_test_runtime_multi_view_and_duplicate_slots(t)
	_test_multi_view_fault_discards_earlier_slot_fire_in_both_modes(t)
	_test_fire_preconditions_do_not_consume_the_arm(t)
	_test_fire_time_fault_closes_without_consumption(t)
	_test_armed_gate_line_is_watched(t)
	_test_duration_and_actor_cleanup_remove_slot_gates(t)
	_test_condition_closed_finite_expiry_roundtrips_to_already_closed(t)
	_test_submit_preflights_external_references(t)
	_test_schema_v8_roundtrip_and_historical_gate_rejection(t)


static func _runtime() -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")
	return rr


static func _matcher() -> EQCondition:
	var condition := EQCondition.new()
	condition.match_target = &"hero"
	condition.require_tags = [&"damage"]
	return condition


static func _reaction(rumination: int = 0) -> EQReservation:
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	definition.duration = EQActionDefinition.DURATION_UNLIMITED
	definition.rumination = rumination
	definition.tags = [&"counter"]
	return EQReservation.new(&"hero", definition)


static func _named(
	name: StringName, condition_id: StringName, type_group: int = EQConditionSpec.Type.NAMED_PREDICATE
) -> EQConditionSpec:
	var spec := EQConditionSpec.new()
	spec.type = type_group as EQConditionSpec.Type
	spec.predicate_name = name
	spec.condition_id = condition_id
	return spec


static func _trigger(rr: EQReservationRuntime, tags: Array[StringName] = [&"damage"]):
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.IMMEDIATE
	definition.tags = tags
	var reservation := EQReservation.new(&"orc", definition)
	reservation.target_id = &"hero"
	rr.submit(reservation)
	return rr.resolve_next()


static func _count_trace(rr: EQReservationRuntime, kind: String, closed_by: String = "") -> int:
	var count := 0
	for record in rr.runtime.trace().records():
		if String(record.get("kind", "")) != kind:
			continue
		if closed_by != "" and String(record.get("closed_by", "")) != closed_by:
			continue
		count += 1
	return count


static func _test_engine_preview_is_non_mutating_and_single_commit(t) -> void:
	var engine := EQTriggerEngine.new()
	var armed := _reaction(1)
	t.ok(engine.arm(armed, _matcher(), 0), "direct engine arm succeeds")
	var previews := engine.preview_event_resolved_occurrences(
		{"kind": &"hit", "source": &"orc", "target": &"hero", "tags": [&"damage"]}, 0
	)
	t.eq(previews.size(), 1, "matching event produces one preview")
	t.eq(armed.status, EQReservation.Status.ARMED, "preview leaves status ARMED")
	t.eq(armed.remaining_ruminations, 1, "preview does not consume rumination")
	t.eq(engine.armed_count(), 1, "preview leaves arm membership")
	t.ok(engine.commit_occurrence(previews[0]), "current preview commits once")
	t.eq(armed.remaining_ruminations, 0, "commit consumes exactly one rumination")
	t.ok(not engine.commit_occurrence(previews[0]), "stale preview cannot commit twice")
	var next := engine.preview_event_resolved_occurrences(
		{"kind": &"hit", "source": &"orc", "target": &"hero", "tags": [&"damage"]}, 0
	)
	t.ok(engine.invalidate_occurrence(next[0]), "current preview can invalidate the slot")
	t.eq(armed.status, EQReservation.Status.INVALIDATED, "invalidation closes the arm")
	t.eq(engine.armed_count(), 0, "invalidated preview removes membership")


static func _test_preview_filters_expiry_without_mutation(t) -> void:
	var engine := EQTriggerEngine.new()
	var armed := _reaction()
	armed.definition.duration = 1
	t.ok(engine.arm(armed, _matcher(), 0), "finite direct arm succeeds")
	var previews := engine.preview_event_resolved_occurrences(
		{"target": &"hero", "tags": [&"damage"]}, 2
	)
	t.eq(previews.size(), 0, "pure preview filters an expired candidate")
	t.eq(engine.armed_count(), 1, "pure preview does not remove expired membership")
	t.eq(armed.status, EQReservation.Status.ARMED, "pure preview leaves expired status unchanged")
	t.eq(
		engine.on_event_resolved_occurrences({"target": &"hero", "tags": [&"damage"]}, 2).size(),
		0,
		"compatibility sweep applies expiry before matching"
	)
	t.eq(engine.armed_count(), 0, "compatibility sweep preserves observable expiry")


static func _test_named_solve_waits_then_fires_with_composite_view(t) -> void:
	var rr := _runtime()
	var state := {"inside": false, "calls": 0, "views": []}
	rr.runtime.register_predicate(
		&"space.in_trap",
		func(view: Dictionary) -> bool:
			state["calls"] += 1
			state["views"].append(view.duplicate(true))
			# The predicate owns only a deep-copy; this mutation must not rewrite cause.
			view["trigger"]["source"] = "predicate_mutated"
			return bool(state["inside"])
	)
	var armed := _reaction(1)
	armed.definition.solve_conditions = [_named(&"space.in_trap", &"trap_open")]
	rr.submit(armed, _matcher())

	_trigger(rr)
	t.eq(_count_trace(rr, "reaction_fired"), 0, "false named solve creates no FIRE")
	t.eq(rr.pending().size(), 0, "false solve leaves no scheduled occurrence")
	t.eq(rr.armed_for(&"hero").size(), 1, "false solve retains the same arm")
	t.eq(armed.status, EQReservation.Status.ARMED, "false solve remains ARMED")
	t.eq(armed.remaining_ruminations, 1, "false solve consumes no rumination")

	state["inside"] = true
	_trigger(rr)
	t.eq(_count_trace(rr, "reaction_fired"), 1, "later true solve schedules exactly one FIRE")
	t.eq(rr.pending().size(), 1, "true solve produces one pending FIRE occurrence")
	t.eq(armed.remaining_ruminations, 0, "accepted FIRE commits one rumination")
	t.eq(state["calls"], 2, "named solve is evaluated once per matching trigger")
	var first_view: Dictionary = state["views"][0]
	t.eq(first_view["trigger"]["source"], "orc", "gate view includes canonical trigger")
	t.eq(first_view["reaction"]["source"], &"hero", "gate view includes reaction owner")
	var pending: EQReservation = rr.pending()[0]
	var context := rr.reaction_fire_context_for_event(pending.event_id)
	t.eq(context["trigger"]["source"], "orc", "predicate mutation cannot rewrite FIRE cause")
	rr.resolve_next()
	t.eq(state["calls"], 2, "scheduled FIRE resolution never re-evaluates its armed gate")


static func _test_invalidation_wins_before_commit(t) -> void:
	var rr := _runtime()
	rr.runtime.register_predicate(&"always.solve", func(_view): return true)
	rr.runtime.register_predicate(&"always.cut", func(_view): return true)
	var armed := _reaction(2)
	armed.definition.solve_conditions = [_named(&"always.solve", &"ready")]
	armed.definition.invalidation_conditions = [_named(&"always.cut", &"cut")]
	rr.submit(armed, _matcher())
	_trigger(rr)
	t.eq(_count_trace(rr, "reaction_fired"), 0, "invalidation-wins schedules no FIRE")
	t.eq(_count_trace(rr, "event_invalidated", "cut"), 1, "declared condition closes the arm")
	t.eq(rr.armed_for(&"hero").size(), 0, "invalidation removes arm membership")
	t.eq(armed.status, EQReservation.Status.INVALIDATED, "invalidation sets slot status")
	t.eq(armed.remaining_ruminations, 2, "invalidation does not consume rumination")
	t.eq(rr._armed_reaction_gates.size(), 0, "condition invalidation removes private gate state")


static func _test_counter_binds_once_and_closes_after_accepted_fires(t) -> void:
	var rr := _runtime()
	var allow := {"value": false}
	rr.runtime.register_predicate(&"allow.fire", func(_view): return bool(allow["value"]))
	var counter := EQConditionSpec.new()
	counter.type = EQConditionSpec.Type.COUNTER
	counter.counter_start = 2
	counter.condition_id = &"uses"
	var armed := _reaction(10)
	armed.definition.solve_conditions = [_named(&"allow.fire", &"allowed")]
	armed.definition.invalidation_conditions = [counter]
	rr.submit(armed, _matcher())
	var counter_ids := rr.lines.line_ids().filter(
		func(id): return String(id).begins_with("eqm.counter.")
	)
	t.eq(counter_ids.size(), 1, "COUNTER issues once at arm time")
	var counter_id: StringName = counter_ids[0]
	t.eq(rr.lines.value_of(counter_id), 2, "bound counter starts at its declaration")

	_trigger(rr)
	t.eq(rr.lines.value_of(counter_id), 2, "WAIT does not decrement the counter")
	t.eq(rr.lines.line_ids().filter(func(id): return String(id).begins_with("eqm.counter.")).size(), 1, "WAIT does not rebind a counter")
	allow["value"] = true
	_trigger(rr)
	t.eq(rr.lines.value_of(counter_id), 1, "first accepted FIRE decrements once")
	t.eq(rr.armed_for(&"hero").size(), 1, "counter remains armed above zero")
	rr.resolve_next()
	_trigger(rr)
	t.eq(rr.lines.value_of(counter_id), 0, "second accepted FIRE exhausts the counter")
	t.eq(rr.armed_for(&"hero").size(), 0, "counter exhaustion closes immediately")
	t.eq(_count_trace(rr, "event_invalidated", "uses"), 1, "counter closure names its condition")
	t.eq(_count_trace(rr, "reaction_fired"), 2, "exactly two accepted FIREs were scheduled")
	t.eq(rr._armed_reaction_gates.size(), 0, "counter closure removes private gate state")
	t.eq(rr._armed_gate_watched_counts.size(), 0, "counter closure removes watched-line ownership")


static func _test_runtime_multi_view_and_duplicate_slots(t) -> void:
	var rr := _runtime()
	var shared := _reaction()
	var counter := EQConditionSpec.new()
	counter.type = EQConditionSpec.Type.COUNTER
	counter.counter_start = 1
	counter.condition_id = &"one_use"
	shared.definition.invalidation_conditions = [counter]
	rr.submit(shared, _matcher())
	rr.submit(shared, _matcher())
	t.eq(rr.engine.armed_count(), 2, "the same reservation can occupy two exact arm slots")
	var counter_ids := rr.lines.line_ids().filter(
		func(id): return String(id).begins_with("eqm.counter.")
	)
	t.eq(counter_ids.size(), 2, "each duplicate arm slot owns a distinct counter")
	rr._sweep_bundle(
		[
			{
				"event_id": 10,
				"view_index": 0,
				"view": {"source": &"orc", "target": &"hero", "tags": [&"damage"]},
			},
			{
				"event_id": 10,
				"view_index": 1,
				"view": {"source": &"orc", "target": &"hero", "tags": [&"damage"]},
			},
		]
	)
	t.eq(_count_trace(rr, "reaction_fired"), 2, "one-use duplicate slots FIRE once each across multi-view input")
	t.eq(rr.engine.armed_count(), 0, "counter closure removes both exact slots")
	for counter_id in counter_ids:
		t.eq(rr.lines.value_of(counter_id), 0, "each slot counter decrements exactly once")
	t.eq(_count_trace(rr, "event_invalidated", "condition_fault"), 0, "slot cleanup never degrades into a missing-gate fault")


static func _test_multi_view_fault_discards_earlier_slot_fire_in_both_modes(t) -> void:
	for shipped in [false, true]:
		var rr := _runtime()
		if shipped:
			rr.runtime.set_mode(rr.runtime.Mode.SHIPPED)
		var calls := {"value": 0}
		rr.runtime.register_predicate(
			&"removed.after.first",
			func(_view):
				calls["value"] += 1
				if calls["value"] == 1:
					rr.runtime._predicates.erase(&"removed.after.first")
				return true
		)
		var armed := _reaction(2)
		armed.definition.solve_conditions = [
			_named(&"removed.after.first", &"durable")
		]
		rr.submit(armed, _matcher())
		rr._sweep_bundle(
			[
				{"event_id": 20, "view_index": 0, "view": {
					"source": &"orc", "target": &"hero", "tags": [&"damage"],
				}},
				{"event_id": 20, "view_index": 1, "view": {
					"source": &"orc", "target": &"hero", "tags": [&"damage"],
				}},
			]
		)
		var mode_name := "SHIPPED" if shipped else "DEV"
		t.eq(_count_trace(rr, "reaction_fired"), 0,
			"%s discards the earlier accepted view when the same slot later faults" % mode_name)
		t.eq(rr.pending().size(), 0, "%s schedules no partial FIRE" % mode_name)
		t.eq(armed.remaining_ruminations, 2, "%s consumes no use on slot fault" % mode_name)
		t.eq(rr.engine.armed_count(), 0, "%s closes the faulted slot fail-safe" % mode_name)
		t.eq(rr._armed_reaction_gates.size(), 0, "%s removes the faulted gate" % mode_name)


static func _test_fire_preconditions_do_not_consume_the_arm(t) -> void:
	var limited := _runtime()
	limited.runtime.set_mode(limited.runtime.Mode.SHIPPED)
	limited.max_cascade_rounds = 0
	var limited_arm := _reaction(2)
	limited.submit(limited_arm, _matcher())
	_trigger(limited)
	t.eq(_count_trace(limited, "reaction_fired"), 0, "cascade budget rejection schedules no FIRE")
	t.eq(limited_arm.remaining_ruminations, 2, "cascade budget rejection consumes no rumination")

	var invalid_view := _runtime()
	invalid_view.runtime.set_mode(invalid_view.runtime.Mode.SHIPPED)
	var invalid_arm := _reaction(1)
	invalid_view.submit(invalid_arm, _matcher())
	invalid_view._sweep_bundle(
		[
			{
				"event_id": 1,
				"view_index": 0,
				"view": {
					"source": &"orc",
					"target": &"hero",
					"tags": [&"damage"],
					"invalid": RefCounted.new(),
				},
			}
		]
	)
	t.eq(_count_trace(invalid_view, "reaction_fired"), 0, "non-serializable cause schedules no FIRE")
	t.eq(invalid_arm.remaining_ruminations, 1, "invalid cause consumes no rumination")
	t.eq(invalid_view.engine.armed_count(), 1, "invalid cause leaves the arm retryable")

	var removed := _runtime()
	removed.runtime.set_mode(removed.runtime.Mode.SHIPPED)
	removed.runtime.register_predicate(
		&"remove.owner",
		func(_view):
			removed.runtime.registry.unregister(&"hero")
			return true
	)
	var removed_arm := _reaction(1)
	removed_arm.definition.solve_conditions = [_named(&"remove.owner", &"owner_present")]
	removed.submit(removed_arm, _matcher())
	_trigger(removed)
	t.eq(_count_trace(removed, "reaction_fired"), 0, "actor removal during gate evaluation schedules no FIRE")
	t.eq(removed_arm.remaining_ruminations, 1, "schedule preflight failure consumes no rumination")


static func _test_fire_time_fault_closes_without_consumption(t) -> void:
	var rr := _runtime()
	rr.runtime.set_mode(rr.runtime.Mode.SHIPPED)
	rr.runtime.register_predicate(&"removed.later", func(_view): return true)
	var armed := _reaction(2)
	armed.definition.solve_conditions = [_named(&"removed.later", &"durable")]
	rr.submit(armed, _matcher())
	rr.runtime._predicates.erase(&"removed.later")
	_trigger(rr)
	t.eq(_count_trace(rr, "reaction_fired"), 0, "FIRE-time predicate fault schedules no occurrence")
	t.eq(_count_trace(rr, "event_invalidated", "condition_fault"), 1, "FIRE-time fault closes fail-safe")
	t.eq(armed.remaining_ruminations, 2, "FIRE-time fault consumes no rumination")
	t.eq(rr.engine.armed_count(), 0, "faulted arm cannot retry as a false green")
	t.eq(rr._armed_reaction_gates.size(), 0, "fault closure removes private gate state")


static func _test_armed_gate_line_is_watched(t) -> void:
	var rr := _runtime()
	rr.lines.issue(&"charge", 5, 1)
	var threshold := EQConditionSpec.new()
	threshold.type = EQConditionSpec.Type.LINE_THRESHOLD
	threshold.line_id = &"charge"
	threshold.threshold = 2
	threshold.relative = true
	threshold.comparison = EQConditionSpec.Comparison.GE
	threshold.condition_id = &"charged"
	var armed := _reaction()
	armed.definition.solve_conditions = [threshold]
	rr.submit(armed, _matcher())
	var row: Dictionary = EQSaveAdapter.save(rr.runtime, rr)["armed_triggers"][0]
	t.eq(row["solve"][0]["threshold"], 7, "relative threshold anchors at arm time")
	rr.step_tick()
	rr.step_tick()
	t.eq(rr.lines.value_of(&"charge"), 7, "arm-only watched line advances while waiting")
	_trigger(rr)
	t.eq(_count_trace(rr, "reaction_fired"), 1, "held anchored threshold permits FIRE")


static func _test_duration_and_actor_cleanup_remove_slot_gates(t) -> void:
	var expiry := _runtime()
	var expiring := _reaction()
	expiring.definition.duration = 1
	expiry.submit(expiring, _matcher())
	t.eq(expiry._armed_reaction_gates.size(), 1, "finite arm owns one gate")
	expiry.step_tick()
	expiry.resolve_one_scheduled_event()
	t.eq(expiry.engine.armed_count(), 0, "duration event closes the exact arm slot")
	t.eq(expiry._armed_reaction_gates.size(), 0, "duration closure removes its gate")

	var departure := _runtime()
	departure.submit(_reaction(), _matcher())
	t.eq(departure._armed_reaction_gates.size(), 1, "departure fixture owns one gate")
	departure.invalidate_actor(&"hero")
	t.eq(departure.engine.armed_count(), 0, "actor departure disarms its slot")
	t.eq(departure._armed_reaction_gates.size(), 0, "actor departure removes its gate")


static func _test_condition_closed_finite_expiry_roundtrips_to_already_closed(t) -> void:
	var original := _runtime()
	original.runtime.register_predicate(&"close.now", func(_view): return true)
	var armed := _reaction(2)
	armed.definition.duration = 1
	armed.definition.invalidation_conditions = [_named(&"close.now", &"cut")]
	original.submit(armed, _matcher())
	_trigger(original)
	t.eq(original.engine.armed_count(), 0, "condition closes the finite arm before duration")
	t.eq(original._armed_reaction_gates.size(), 0, "closed finite arm retains no private gate")
	t.eq(original._expiry_by_event.size(), 1, "its observable expiry event remains scheduled")
	var bundle := EQSaveAdapter.save(original.runtime, original)

	var restored := EQReservationRuntime.new()
	restored.runtime.emit_engine_diagnostics = false
	restored.runtime.register_predicate(&"close.now", func(_view): return true)
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored),
		"schema v8 restores a condition-closed finite expiry")
	t.eq(EQSaveAdapter.save(restored.runtime, restored), bundle,
		"condition-closed expiry survives save-load-save exactly")
	restored.step_tick()
	restored.resolve_one_scheduled_event()
	t.eq(_count_trace(restored, "event_invalidated", "already_closed"), 1,
		"the retained duration event resolves through the documented stale path")
	t.eq(restored._expiry_by_event.size(), 0, "already_closed consumes the expiry ownership")


static func _test_submit_preflights_external_references(t) -> void:
	var rr := _runtime()
	var counter := EQConditionSpec.new()
	counter.type = EQConditionSpec.Type.COUNTER
	counter.counter_start = 2
	var missing_predicate := _named(&"missing", &"missing")
	var bad_predicate := _reaction()
	bad_predicate.definition.solve_conditions = [missing_predicate]
	bad_predicate.definition.invalidation_conditions = [counter]
	rr.submit(bad_predicate, _matcher())
	t.eq(rr.armed_for(&"hero").size(), 0, "unregistered predicate rejects before arm")
	t.eq(rr.runtime.scheduler.size(), 0, "rejected arm schedules no expiry/FIRE")
	t.eq(rr.lines.to_dict()["counter_seq"], 0, "preflight prevents counter-line leak")
	t.eq(rr.runtime.faults.back()["code"], EQError.CONDITION_PREDICATE_UNREGISTERED, "predicate rejection uses stable code")

	var missing_line := EQConditionSpec.new()
	missing_line.type = EQConditionSpec.Type.LINE_THRESHOLD
	missing_line.line_id = &"missing.line"
	var bad_line := _reaction()
	bad_line.definition.solve_conditions = [missing_line]
	rr.submit(bad_line, _matcher())
	t.eq(rr.armed_for(&"hero").size(), 0, "unknown line also rejects before arm")
	t.eq(rr.runtime.faults.back()["code"], EQError.CONDITION_LINE_UNKNOWN, "line rejection uses stable code")


static func _test_schema_v8_roundtrip_and_historical_gate_rejection(t) -> void:
	var original := _runtime()
	original.lines.issue(&"consumer.line", 9, 0)
	var original_allow := {"value": false}
	original.runtime.register_predicate(
		&"durable.gate", func(_view): return bool(original_allow["value"])
	)
	var counter := EQConditionSpec.new()
	counter.type = EQConditionSpec.Type.COUNTER
	counter.counter_start = 2
	counter.condition_id = &"durable_uses"
	var armed := _reaction(3)
	armed.definition.solve_conditions = [_named(&"durable.gate", &"durable")]
	armed.definition.invalidation_conditions = [counter]
	original.submit(armed, _matcher())
	_trigger(original)
	armed.definition.solve_conditions[0].predicate_name = &"mutated.after.arm"
	armed.definition.solve_conditions = []
	armed.definition.invalidation_conditions = []
	var bundle := EQSaveAdapter.save(original.runtime, original)
	t.eq(bundle["schema_version"], 8, "bound reaction gates ship in schema v8")
	var row: Dictionary = bundle["armed_triggers"][0]
	t.ok(row.has("solve") and row.has("inv") and row.has("counter_lines"), "armed row carries all gate fields")
	t.eq(
		row["reservation"]["definition"]["solve_conditions"][0]["predicate_name"],
		"durable.gate",
		"writer persists the arm-time authored predicate after definition mutation"
	)
	t.eq(row["reservation"]["definition"]["invalidation_conditions"].size(), 1, "writer persists the arm-time authored counter array")

	var restored := EQReservationRuntime.new()
	restored.runtime.emit_engine_diagnostics = false
	var restored_allow := {"value": false}
	restored.runtime.register_predicate(
		&"durable.gate", func(_view): return bool(restored_allow["value"])
	)
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "schema v8 gate loads")
	t.eq(EQSaveAdapter.save(restored.runtime, restored), bundle, "save-load-save preserves bound gate exactly")
	original_allow["value"] = true
	restored_allow["value"] = true
	_trigger(original)
	_trigger(restored)
	t.eq(original.pending().size(), 1, "original continuation fires")
	t.eq(restored.pending().size(), 1, "restored continuation fires identically")
	var original_counter: StringName = bundle["armed_triggers"][0]["counter_lines"][0]["line_id"]
	t.eq(restored.lines.value_of(original_counter), original.lines.value_of(original_counter), "restored counter continues from the same line")

	var missing_field: Dictionary = bundle.duplicate(true)
	missing_field["armed_triggers"][0].erase("solve")
	var missing_target := EQReservationRuntime.new()
	missing_target.runtime.emit_engine_diagnostics = false
	missing_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(missing_target.runtime, missing_field, {}, missing_target), "schema v8 rejects a missing gate field")
	t.eq(missing_target.runtime.registry.size(), 0, "gate verification happens before actor mutation")
	t.eq(missing_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "missing gate uses stable state code")

	var wrong_status: Dictionary = bundle.duplicate(true)
	wrong_status["armed_triggers"][0]["reservation"]["status"] = EQReservation.Status.PENDING
	var status_target := EQReservationRuntime.new()
	status_target.runtime.emit_engine_diagnostics = false
	status_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(status_target.runtime, wrong_status, {}, status_target), "schema v8 rejects a non-ARMED unlimited trigger row")
	t.eq(status_target.runtime.registry.size(), 0, "armed status verification happens before actor mutation")
	t.eq(status_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "armed status rejection uses stable gate state code")

	var wrong_kind: Dictionary = bundle.duplicate(true)
	wrong_kind["armed_triggers"][0]["reservation"]["definition"]["kind"] = EQActionDefinition.Kind.IMMEDIATE
	var kind_target := EQReservationRuntime.new()
	kind_target.runtime.emit_engine_diagnostics = false
	kind_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(kind_target.runtime, wrong_kind, {}, kind_target), "schema v8 rejects a non-reaction unlimited trigger row")
	t.eq(kind_target.runtime.registry.size(), 0, "armed kind verification happens before actor mutation")
	t.eq(kind_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "armed kind rejection uses stable gate state code")

	var armed_scalar_tampers := [
		{"name": "duration string", "scope": "definition", "field": "duration", "value": "-1"},
		{"name": "rumination string", "scope": "definition", "field": "rumination", "value": "3"},
		{"name": "remaining string", "scope": "reservation", "field": "remaining_ruminations", "value": "3"},
	]
	for scenario in armed_scalar_tampers:
		var scalar_tamper: Dictionary = bundle.duplicate(true)
		var scalar_reservation: Dictionary = scalar_tamper["armed_triggers"][0]["reservation"]
		if scenario["scope"] == "definition":
			scalar_reservation["definition"][scenario["field"]] = scenario["value"]
		else:
			scalar_reservation[scenario["field"]] = scenario["value"]
		var scalar_target := EQReservationRuntime.new()
		scalar_target.runtime.emit_engine_diagnostics = false
		scalar_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
		t.ok(not EQSaveAdapter.load(scalar_target.runtime, scalar_tamper, {}, scalar_target), "schema v8 rejects armed %s" % scenario["name"])
		t.eq(scalar_target.runtime.registry.size(), 0, "armed scalar type verification happens before actor mutation")
		t.eq(scalar_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "armed scalar type rejection uses stable gate state code")

	var armed_range_tampers := [
		{"name": "zero duration", "scope": "definition", "field": "duration", "value": 0},
		{"name": "negative duration", "scope": "definition", "field": "duration", "value": -2},
		{"name": "negative authored rumination", "scope": "definition", "field": "rumination", "value": -1},
		{"name": "negative remaining rumination", "scope": "reservation", "field": "remaining_ruminations", "value": -1},
		{"name": "remaining above authored rumination", "scope": "reservation", "field": "remaining_ruminations", "value": 4},
	]
	for scenario in armed_range_tampers:
		var range_tamper: Dictionary = bundle.duplicate(true)
		var range_reservation: Dictionary = range_tamper["armed_triggers"][0]["reservation"]
		if scenario["scope"] == "definition":
			range_reservation["definition"][scenario["field"]] = scenario["value"]
		else:
			range_reservation[scenario["field"]] = scenario["value"]
		var range_target := EQReservationRuntime.new()
		range_target.runtime.emit_engine_diagnostics = false
		range_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
		t.ok(not EQSaveAdapter.load(range_target.runtime, range_tamper, {}, range_target), "schema v8 rejects armed %s" % scenario["name"])
		t.eq(range_target.runtime.registry.size(), 0, "armed range verification happens before actor mutation")
		t.eq(range_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "armed range rejection uses stable gate state code")

	var finite_original := _runtime()
	var finite_arm := _reaction(2)
	finite_arm.definition.duration = 2
	finite_original.submit(finite_arm, _matcher())
	var finite_bundle := EQSaveAdapter.save(finite_original.runtime, finite_original)
	var finite_target := EQReservationRuntime.new()
	finite_target.runtime.emit_engine_diagnostics = false
	t.ok(EQSaveAdapter.load(finite_target.runtime, finite_bundle, {}, finite_target), "valid active finite expiry still loads under strict arm verification")
	t.eq(EQSaveAdapter.save(finite_target.runtime, finite_target), finite_bundle, "active finite expiry remains save-load-save exact")

	var invalid_spec_type: Dictionary = bundle.duplicate(true)
	invalid_spec_type["armed_triggers"][0]["reservation"]["definition"]["solve_conditions"][0]["type"] = 99
	var spec_type_target := EQReservationRuntime.new()
	spec_type_target.runtime.emit_engine_diagnostics = false
	spec_type_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(spec_type_target.runtime, invalid_spec_type, {}, spec_type_target), "schema v8 rejects an authored condition type outside the enum")
	t.eq(spec_type_target.runtime.registry.size(), 0, "authored type verification happens before actor mutation")

	var invalid_spec_comparison: Dictionary = bundle.duplicate(true)
	invalid_spec_comparison["armed_triggers"][0]["reservation"]["definition"]["solve_conditions"][0]["comparison"] = 99
	var comparison_target := EQReservationRuntime.new()
	comparison_target.runtime.emit_engine_diagnostics = false
	comparison_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(comparison_target.runtime, invalid_spec_comparison, {}, comparison_target), "schema v8 rejects an authored comparison outside the enum")
	t.eq(comparison_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "authored comparison rejection uses stable gate state code")

	var invalid_spec_field_type: Dictionary = bundle.duplicate(true)
	invalid_spec_field_type["armed_triggers"][0]["reservation"]["definition"]["solve_conditions"][0]["relative"] = 0
	var field_type_target := EQReservationRuntime.new()
	field_type_target.runtime.emit_engine_diagnostics = false
	field_type_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(field_type_target.runtime, invalid_spec_field_type, {}, field_type_target), "schema v8 rejects an authored condition scalar with the wrong type")
	t.eq(field_type_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "authored scalar type rejection uses stable gate state code")

	var bound_type_string: Dictionary = bundle.duplicate(true)
	bound_type_string["armed_triggers"][0]["solve"][0]["type"] = "2"
	var bound_type_target := EQReservationRuntime.new()
	bound_type_target.runtime.emit_engine_diagnostics = false
	bound_type_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(bound_type_target.runtime, bound_type_string, {}, bound_type_target), "schema v8 rejects a string bound term type")
	t.eq(bound_type_target.runtime.registry.size(), 0, "bound type verification happens before actor mutation")

	var bound_threshold_string: Dictionary = bundle.duplicate(true)
	bound_threshold_string["armed_triggers"][0]["inv"][0]["threshold"] = "0"
	var bound_threshold_target := EQReservationRuntime.new()
	bound_threshold_target.runtime.emit_engine_diagnostics = false
	bound_threshold_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(bound_threshold_target.runtime, bound_threshold_string, {}, bound_threshold_target), "schema v8 rejects a string bound threshold")
	t.eq(bound_threshold_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "bound threshold rejection uses stable gate state code")

	var counter_line_id_number: Dictionary = bundle.duplicate(true)
	counter_line_id_number["armed_triggers"][0]["counter_lines"][0]["line_id"] = 1
	var counter_line_type_target := EQReservationRuntime.new()
	counter_line_type_target.runtime.emit_engine_diagnostics = false
	counter_line_type_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(counter_line_type_target.runtime, counter_line_id_number, {}, counter_line_type_target), "schema v8 rejects a non-string counter registry id")
	t.eq(counter_line_type_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "counter registry id type rejection is stable")

	var invalid_counter_start: Dictionary = bundle.duplicate(true)
	invalid_counter_start["armed_triggers"][0]["reservation"]["definition"]["invalidation_conditions"][0]["counter_start"] = 0
	var counter_start_target := EQReservationRuntime.new()
	counter_start_target.runtime.emit_engine_diagnostics = false
	counter_start_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(counter_start_target.runtime, invalid_counter_start, {}, counter_start_target), "schema v8 rejects a non-positive authored counter start")
	t.eq(counter_start_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "counter start rejection uses stable gate state code")

	var out_of_range_counter: Dictionary = bundle.duplicate(true)
	var out_of_range_line := String(out_of_range_counter["armed_triggers"][0]["counter_lines"][0]["line_id"])
	for saved_line in out_of_range_counter["event_lines"]["lines"]:
		if String(saved_line.get("id", "")) == out_of_range_line:
			saved_line["value"] = 3
	var counter_value_target := EQReservationRuntime.new()
	counter_value_target.runtime.emit_engine_diagnostics = false
	counter_value_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(counter_value_target.runtime, out_of_range_counter, {}, counter_value_target), "schema v8 rejects an armed counter above its authored start")
	t.eq(counter_value_target.runtime.registry.size(), 0, "counter value verification happens before actor mutation")

	var exhausted_counter: Dictionary = bundle.duplicate(true)
	var exhausted_line := String(exhausted_counter["armed_triggers"][0]["counter_lines"][0]["line_id"])
	for saved_line in exhausted_counter["event_lines"]["lines"]:
		if String(saved_line.get("id", "")) == exhausted_line:
			saved_line["value"] = 0
	var exhausted_target := EQReservationRuntime.new()
	exhausted_target.runtime.emit_engine_diagnostics = false
	exhausted_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(exhausted_target.runtime, exhausted_counter, {}, exhausted_target), "schema v8 rejects an exhausted counter that is still armed")
	t.eq(exhausted_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "exhausted armed counter rejection is stable")

	var unregistered_target := EQReservationRuntime.new()
	unregistered_target.runtime.emit_engine_diagnostics = false
	t.ok(not EQSaveAdapter.load(unregistered_target.runtime, bundle, {}, unregistered_target), "schema v8 rejects an unregistered gate predicate")
	t.eq(unregistered_target.runtime.registry.size(), 0, "predicate verification happens before actor mutation")
	t.eq(unregistered_target.runtime.faults.back()["code"], EQError.CONDITION_PREDICATE_UNREGISTERED, "unregistered gate predicate uses the registry error")

	var injected_fault: Dictionary = bundle.duplicate(true)
	injected_fault["armed_triggers"][0]["solve"][0]["fault"] = {
		"code": EQError.CONDITION_LINE_UNKNOWN,
		"message": "tampered",
	}
	var fault_target := EQReservationRuntime.new()
	fault_target.runtime.emit_engine_diagnostics = false
	fault_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(fault_target.runtime, injected_fault, {}, fault_target), "schema v8 rejects extra fault payload on a bound term")
	t.eq(fault_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "term-shape tamper uses stable gate state code")

	var aliased_counter: Dictionary = bundle.duplicate(true)
	aliased_counter["armed_triggers"][0]["inv"][0]["line_id"] = "consumer.line"
	aliased_counter["armed_triggers"][0]["counter_lines"][0]["line_id"] = "consumer.line"
	var alias_target := EQReservationRuntime.new()
	alias_target.runtime.emit_engine_diagnostics = false
	alias_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(alias_target.runtime, aliased_counter, {}, alias_target), "schema v8 rejects a counter rebound onto a consumer line")
	t.eq(alias_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "counter alias rejection is stable")

	var cross_gate_alias: Dictionary = bundle.duplicate(true)
	cross_gate_alias["armed_triggers"].append(cross_gate_alias["armed_triggers"][0].duplicate(true))
	var cross_gate_target := EQReservationRuntime.new()
	cross_gate_target.runtime.emit_engine_diagnostics = false
	cross_gate_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(cross_gate_target.runtime, cross_gate_alias, {}, cross_gate_target), "schema v8 rejects one generated counter reused by two armed gates")
	t.eq(cross_gate_target.runtime.registry.size(), 0, "cross-gate counter verification happens before actor mutation")
	t.eq(cross_gate_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "cross-gate counter alias rejection is stable")

	var missing_provenance: Dictionary = bundle.duplicate(true)
	missing_provenance["event_lines"].erase("counter_ids")
	var provenance_target := EQReservationRuntime.new()
	provenance_target.runtime.emit_engine_diagnostics = false
	provenance_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(provenance_target.runtime, missing_provenance, {}, provenance_target), "schema v8 requires generated counter provenance")
	t.eq(provenance_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "missing provenance rejection is stable")

	var no_counter_original := _runtime()
	no_counter_original.submit(_reaction(), _matcher())
	var negative_counter_seq: Dictionary = EQSaveAdapter.save(
		no_counter_original.runtime, no_counter_original
	)
	negative_counter_seq["event_lines"]["counter_seq"] = -1
	var sequence_target := EQReservationRuntime.new()
	sequence_target.runtime.emit_engine_diagnostics = false
	t.ok(not EQSaveAdapter.load(sequence_target.runtime, negative_counter_seq, {}, sequence_target), "schema v8 rejects a negative empty counter sequence")
	t.eq(sequence_target.runtime.registry.size(), 0, "counter sequence verification happens before actor mutation")
	t.eq(sequence_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "counter sequence rejection uses stable gate state code")

	var historical: Dictionary = bundle.duplicate(true)
	historical["schema_version"] = 7
	for key in ["solve", "inv", "counter_lines"]:
		historical["armed_triggers"][0].erase(key)
	var historical_target := EQReservationRuntime.new()
	historical_target.runtime.emit_engine_diagnostics = false
	historical_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(historical_target.runtime, historical, {}, historical_target), "v7 conditioned arm is rejected instead of rebound")
	t.eq(historical_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "historical gate rejection is stable")

	var empty_original := _runtime()
	empty_original.submit(_reaction(), _matcher())
	var empty_v7: Dictionary = EQSaveAdapter.save(empty_original.runtime, empty_original)
	empty_v7["schema_version"] = 7
	for key in ["solve", "inv", "counter_lines"]:
		empty_v7["armed_triggers"][0].erase(key)
	var empty_target := EQReservationRuntime.new()
	empty_target.runtime.emit_engine_diagnostics = false
	t.ok(EQSaveAdapter.load(empty_target.runtime, empty_v7, {}, empty_target), "v7 empty-gate arm migrates")
	t.eq(empty_target.armed_for(&"hero").size(), 1, "historical empty arm is restored")
