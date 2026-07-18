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
	_test_fire_preconditions_do_not_consume_the_arm(t)
	_test_fire_time_fault_closes_without_consumption(t)
	_test_armed_gate_line_is_watched(t)
	_test_duration_and_actor_cleanup_remove_slot_gates(t)
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

	var missing_provenance: Dictionary = bundle.duplicate(true)
	missing_provenance["event_lines"].erase("counter_ids")
	var provenance_target := EQReservationRuntime.new()
	provenance_target.runtime.emit_engine_diagnostics = false
	provenance_target.runtime.register_predicate(&"durable.gate", func(_view): return false)
	t.ok(not EQSaveAdapter.load(provenance_target.runtime, missing_provenance, {}, provenance_target), "schema v8 requires generated counter provenance")
	t.eq(provenance_target.runtime.faults.back()["code"], EQError.REACTION_FIRE_GATE_STATE_INVALID, "missing provenance rejection is stable")

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
