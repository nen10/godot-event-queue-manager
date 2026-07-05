extends RefCounted
## EQM-127: v3 snapshot compatibility with additive `relations` and
## `state_algebra` tables plus verify-before-mutate protections.

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQRelationGraph := preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")
const EQStateAlgebra := preload("res://addons/event_queue_manager/runtime/eq_state_algebra.gd")
const EQSaveAdapter := preload("res://addons/event_queue_manager/runtime/eq_save_adapter.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_v3_roundtrip(t)
	_test_v2_bundle_without_new_tables(t)
	_test_schema_v4_rejected(t)
	_test_detached_relations_rejected(t)
	_test_unregistered_maintenance_predicate_rejected(t)
	_test_restore_does_not_emit_state_wrapped(t)


static func _pipeline_base() -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")

	_register_handlers(rr)
	rr.lines.issue(&"ct.hero", 0, 5)

	var gated := EQActionDefinition.new()
	gated.kind = EQActionDefinition.Kind.IMMEDIATE
	gated.effect_name = &"strike"
	var gate_spec := EQConditionSpec.new()
	gate_spec.type = EQConditionSpec.Type.LINE_THRESHOLD
	gate_spec.line_id = &"ct.hero"
	gate_spec.threshold = 100
	gated.solve_conditions = [gate_spec]

	var reaction := EQActionDefinition.new()
	reaction.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	reaction.duration = 50
	var cond := EQCondition.new()
	cond.match_target = &"hero"
	cond.require_tags = [&"damage"]

	var prep := EQActionDefinition.new()
	prep.kind = EQActionDefinition.Kind.PREPARED
	prep.delay = 30

	rr.submit(EQReservation.new(&"hero", gated))
	rr.submit(EQReservation.new(&"hero", reaction), cond)
	rr.submit(EQReservation.new(&"orc", prep))

	return rr


static func _attach_relation_graph(rr: EQReservationRuntime, maintenance_predicate: StringName) -> void:
	rr.relations = EQRelationGraph.new(rr.runtime.trace())
	var type_decl := {
		"name": &"ally",
		"category": &"social",
		"inverse": &"",
		"structure": EQRelationGraph.Structure.GRAPH,
		"maintenance": {
			"type": EQConditionSpec.Type.NAMED_PREDICATE,
			"predicate_name": String(maintenance_predicate),
		},
		"sweep": &"eqm.sweep.primary_threshold",
		"on_dissolve": EQRelationGraph.Dissolve.NONE,
	}
	rr.relations.declare_relation_type(type_decl)
	rr.relations.bind(&"ally", &"hero", &"orc")


static func _attach_state_algebra(rr: EQReservationRuntime) -> void:
	rr.state_algebra = EQStateAlgebra.new(rr.lines, rr.runtime.trace())
	rr.state_algebra.declare_inv_pair(&"focus", &"exhausted", EQStateAlgebra.Rule.CANCEL)
	rr.state_algebra.grant_state(&"hero", &"focus", 2)
	rr.state_algebra.wrap_state(&"hero", &"focus", {"name": &"focus_shield", "params": {"depth": 2}})


static func _attach_modded_pending(rr: EQReservationRuntime) -> void:
	rr.lines.add_rate_modifier(&"ct.hero", "add", 1)
	var pending := EQActionDefinition.new()
	pending.kind = EQActionDefinition.Kind.IMMEDIATE
	pending.effect_name = &"strike"
	var pending_cond := EQConditionSpec.new()
	pending_cond.type = EQConditionSpec.Type.LINE_THRESHOLD
	pending_cond.line_id = &"ct.hero"
	pending_cond.threshold = 9999
	pending.solve_conditions = [pending_cond]
	var pending_res := EQReservation.new(&"hero", pending)
	pending_res.provenance = [{"origin": "eqm_snapshot_v3", "tier": 1}]
	rr.submit(pending_res)


static func _pipeline_setup_v3(maintenance_predicate: StringName = &"v3_maintenance") -> EQReservationRuntime:
	var rr := _pipeline_base()
	_attach_relation_graph(rr, maintenance_predicate)
	_attach_state_algebra(rr)
	_attach_modded_pending(rr)
	return rr


static func _loader_runtime(maintenance_predicate: StringName = StringName(), register_predicate: bool = true) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	_register_handlers(rr)
	if register_predicate and maintenance_predicate != StringName():
		rr.runtime.register_predicate(maintenance_predicate, func(_ctx) -> bool:
			return true)
	rr.relations = EQRelationGraph.new(rr.runtime.trace())
	rr.state_algebra = EQStateAlgebra.new(rr.lines, rr.runtime.trace())
	return rr


static func _register_handlers(rr: EQReservationRuntime) -> void:
	rr.runtime.register_effect(&"strike", func(_v) -> Array:
		var rec := EQEffectRecord.new()
		rec.kind = &"strike"
		return [rec])


static func _continuation(rr: EQReservationRuntime) -> Array:
	var order := []
	for _i in 30:
		rr.step_tick()
		var res = rr.resolve_next()
		if res != null:
			order.append([rr.runtime.scheduler.current_tick, String(res.actor_id)])
	return order


static func _trace_suffix_without_index(trace_records: Array, start: int) -> Array:
	var out := []
	for i in range(start, trace_records.size()):
		var rec: Dictionary = (trace_records[i] as Dictionary).duplicate(true)
		rec.erase("i")
		out.append(rec)
	return out


static func _pending_provenance_list(rr: EQReservationRuntime) -> Array:
	var out := []
	for p in rr.pending_conditional():
		var res: EQReservation = p
		if res != null:
			out.append(res.provenance.duplicate(true))
	return out


static func _has_trace_kind(trace_records: Array, want: String) -> bool:
	for rec in trace_records:
		if String(rec.get("kind", "")) == want:
			return true
	return false


static func _test_v3_roundtrip(t) -> void:
	var original := _pipeline_setup_v3()
	var bundle := EQSaveAdapter.save(original.runtime, original)
	t.ok(not bundle.is_empty(), "v3 bundle saves")

	var restored := _loader_runtime(&"v3_maintenance", true)
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "v3 bundle loads with attached relation graph / state algebra")
	t.eq(restored.armed_for(&"hero").size(), original.armed_for(&"hero").size(), "armed triggers survived")
	t.eq(restored.pending_conditional().size(), original.pending_conditional().size(), "pending reservations survived")
	t.eq(restored.relations.to_dict(), original.relations.to_dict(), "relations table restored")
	t.eq(restored.state_algebra.to_dict(), original.state_algebra.to_dict(), "state_algebra table restored")
	t.eq(restored.lines.to_dict(), original.lines.to_dict(), "event_lines with modifiers restored")
	t.eq(restored.state_algebra.stacks_of(&"hero", &"focus"), original.state_algebra.stacks_of(&"hero", &"focus"), "axis stack restored")
	t.eq(_pending_provenance_list(restored), _pending_provenance_list(original), "provenance on pending reservations restored")

	var original_trace_start := original.runtime.trace().size()
	var restored_trace_start := restored.runtime.trace().size()
	var original_order := _continuation(original)
	var restored_order := _continuation(restored)
	t.eq(restored_order, original_order, "continuation pop order is identical")
	t.eq(
		_trace_suffix_without_index(restored.runtime.trace().records(), restored_trace_start),
		_trace_suffix_without_index(original.runtime.trace().records(), original_trace_start),
		"continuation trace is identical")


static func _test_v2_bundle_without_new_tables(t) -> void:
	var rr := _pipeline_setup_v3()
	var bundle := EQSaveAdapter.save(rr.runtime, rr)
	bundle.erase("relations")
	bundle.erase("state_algebra")

	var fresh := EQReservationRuntime.new()
	fresh.runtime.emit_engine_diagnostics = false
	_register_handlers(fresh)
	var before_faults := fresh.runtime.faults.size()
	var before_trace := fresh.runtime.trace().size()
	t.ok(EQSaveAdapter.load(fresh.runtime, bundle, {}, fresh), "v2 bundle without new tables loads")
	t.eq(fresh.runtime.faults.size(), before_faults, "missing tables do not create faults")
	t.eq(fresh.runtime.trace().size(), before_trace, "missing tables do not create trace")
	t.eq(fresh.relations, null, "missing relations table keeps runtime detached")
	t.eq(fresh.state_algebra, null, "missing state_algebra table keeps runtime detached")


static func _test_schema_v4_rejected(t) -> void:
	var rr := _pipeline_setup_v3()
	var bundle := EQSaveAdapter.save(rr.runtime, rr)
	bundle["schema_version"] = 4

	var fresh := EQReservationRuntime.new()
	fresh.runtime.emit_engine_diagnostics = false
	_register_handlers(fresh)
	t.ok(not EQSaveAdapter.load(fresh.runtime, bundle, {}, fresh), "schema 4 is rejected")


static func _test_detached_relations_rejected(t) -> void:
	var rr := _pipeline_setup_v3()
	var bundle := EQSaveAdapter.save(rr.runtime, rr)
	bundle["relations"] = {
		"relation_types": [{
			"name": &"solo",
			"category": &"social",
			"inverse": &"",
			"structure": EQRelationGraph.Structure.GRAPH,
			"maintenance": null,
			"sweep": &"eqm.sweep.primary_threshold",
			"on_dissolve": EQRelationGraph.Dissolve.NONE,
		}],
		"relations": [{"relation_id": &"eqm.rel.1", "type": &"solo", "from": &"hero", "to": &"orc"}],
		"relation_seq": 1,
	}

	var detached := EQReservationRuntime.new()
	detached.runtime.emit_engine_diagnostics = false
	var before := detached.runtime.scheduler.snapshot()
	var before_lines := detached.lines.to_dict()
	var before_faults := detached.runtime.faults.size()
	t.ok(not EQSaveAdapter.load(detached.runtime, bundle, {}, detached), "non-empty relations table rejects detached runtime")
	t.eq(detached.runtime.faults.back()["code"], EQError.CONDITION_LINE_UNKNOWN, "relation attachment is a stable error")
	t.eq(detached.runtime.faults.size(), before_faults + 1, "exactly one fault is recorded")
	t.eq(detached.runtime.scheduler.snapshot(), before, "load failure keeps scheduler state")
	t.eq(detached.lines.to_dict(), before_lines, "load failure keeps event lines")


static func _test_unregistered_maintenance_predicate_rejected(t) -> void:
	var predicate := &"unregistered_maintenance"
	var rr := _pipeline_setup_v3(predicate)
	var bundle := EQSaveAdapter.save(rr.runtime, rr)

	var fresh := _loader_runtime(predicate, false)
	var before := fresh.runtime.scheduler.snapshot()
	var before_lines := fresh.lines.to_dict()
	var before_faults := fresh.runtime.faults.size()
	t.ok(not EQSaveAdapter.load(fresh.runtime, bundle, {}, fresh), "unregistered maintenance predicate rejects the load")
	t.eq(fresh.runtime.faults.back()["code"], EQError.CONDITION_PREDICATE_UNREGISTERED, "maintenance predicate is verified before mutation")
	t.eq(fresh.runtime.faults.size(), before_faults + 1, "exactly one fault is recorded")
	t.eq(fresh.runtime.scheduler.snapshot(), before, "load failure keeps scheduler state")
	t.eq(fresh.lines.to_dict(), before_lines, "load failure keeps event lines")
	t.eq(fresh.runtime.registry.size(), 0, "verify-before-mutate keeps actors unloaded")


static func _test_restore_does_not_emit_state_wrapped(t) -> void:
	var rr := _pipeline_setup_v3()
	var bundle := EQSaveAdapter.save(rr.runtime, rr)

	var restored := _loader_runtime(&"v3_maintenance", true)
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "load succeeds for trace emission proof")
	t.eq(_has_trace_kind(restored.runtime.trace().records(), "state_wrapped"), false, "state_wrapped trace is not emitted during restore")
