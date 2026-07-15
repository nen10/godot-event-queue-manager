extends RefCounted
## EQM-117: save bundle v2 (SEM §10, Q41) — boundary-gated save, additive
## pipeline tables, v1 migrator, unknown-version rejection, verify-before-mutate
## load, and a roundtrip crossing lines/conditions/armed reactions.

const EQReservationRuntime := preload(
	"res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd"
)
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQEffectCommitResult := preload(
	"res://addons/event_queue_manager/runtime/eq_effect_commit_result.gd"
)
const EQSaveAdapter := preload("res://addons/event_queue_manager/runtime/eq_save_adapter.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_save_gate(t)
	_test_bundle_shape(t)
	_test_v1_migrator_and_unknown(t)
	_test_verify_before_mutate(t)
	_test_effect_result_binding_verify_before_mutate(t)
	_test_historical_missing_binding_loads_as_legacy(t)
	_test_historical_schema_rejects_typed_binding(t)
	_test_schema_v4_requires_bindings(t)
	_test_roundtrip_continuation(t)


static func _pipeline_setup() -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")
	rr.runtime.register_effect(
		&"strike",
		func(_v) -> Array:
			var rec := EQEffectRecord.new()
			rec.kind = &"strike"
			return [rec]
	)
	rr.lines.issue(&"ct.hero", 0, 5)
	# condition-gated action (resolves when ct reaches 100)
	var gated := EQActionDefinition.new()
	gated.kind = EQActionDefinition.Kind.IMMEDIATE
	gated.effect_name = &"strike"
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.LINE_THRESHOLD
	spec.line_id = &"ct.hero"
	spec.threshold = 100
	gated.solve_conditions = [spec]
	rr.submit(EQReservation.new(&"hero", gated))
	# armed reaction with a duration (schedules its expiry event)
	var reaction := EQActionDefinition.new()
	reaction.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	reaction.duration = 50
	var cond := EQCondition.new()
	cond.match_target = &"hero"
	cond.require_tags = [&"damage"]
	rr.submit(EQReservation.new(&"hero", reaction), cond)
	# a scheduled prepared action for the orc
	var prep := EQActionDefinition.new()
	prep.kind = EQActionDefinition.Kind.PREPARED
	prep.delay = 30
	rr.submit(EQReservation.new(&"orc", prep))
	return rr


static func _register_handlers(rr: EQReservationRuntime) -> void:
	rr.runtime.register_effect(
		&"strike",
		func(_v) -> Array:
			var rec := EQEffectRecord.new()
			rec.kind = &"strike"
			return [rec]
	)


static func _test_save_gate(t) -> void:
	var rr := _pipeline_setup()
	var rec := EQEffectRecord.new()
	rr.chunk.add(rec)
	t.eq(
		EQSaveAdapter.save(rr.runtime, rr), {}, "a non-empty chunk blocks the save (boundary, §10)"
	)
	t.eq(
		rr.runtime.faults.back()["code"],
		EQError.SAVE_BLOCKED,
		"blocked save is a stable error, no force flag"
	)
	rr.chunk.drain()
	rr.open_window(&"hero", &"command")
	t.eq(EQSaveAdapter.save(rr.runtime, rr), {}, "an open explicit window blocks the save")
	rr.close_window()
	t.ok(not EQSaveAdapter.save(rr.runtime, rr).is_empty(), "the boundary allows the save")


static func _test_bundle_shape(t) -> void:
	var rr := _pipeline_setup()
	var bundle := EQSaveAdapter.save(rr.runtime, rr)
	var schema_version := int(bundle["schema_version"])
	t.eq(schema_version, 5, "bundle saves at the current schema v5")
	for key in [
		"event_lines", "windows", "armed_triggers", "pending_conditional", "scheduled_reservations"
	]:
		t.ok(bundle.has(key), "bundle carries the %s table" % key)
	t.eq((bundle["armed_triggers"] as Array).size(), 1, "armed reaction serialized")
	t.eq(
		(bundle["pending_conditional"] as Array).size(), 1, "condition-gated reservation serialized"
	)
	t.ok(
		(bundle["armed_triggers"] as Array)[0]["expiry_event_id"] > 0,
		"the reaction's expiry event link survives"
	)
	t.ok(
		not EQSaveAdapter.contains_live_object(bundle),
		"the bundle contains no live object (Adapter rule)"
	)


static func _test_v1_migrator_and_unknown(t) -> void:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	var v1 := {
		"schema_version": 1,
		"scheduler": rr.runtime.scheduler.snapshot(),
		"actors": [{"actor_id": "hero", "data": {"hp": 3}}]
	}
	var fresh := EQReservationRuntime.new()
	fresh.runtime.emit_engine_diagnostics = false
	t.ok(
		EQSaveAdapter.load(fresh.runtime, v1, {}, fresh),
		"a v1 bundle loads (missing tables = empty, the migrator)"
	)
	t.eq(int(fresh.runtime.registry.get_state(&"hero").data["hp"]), 3, "v1 actor data restored")
	t.ok(
		not EQSaveAdapter.load(fresh.runtime, {"schema_version": 6}),
		"a newer schema is rejected cleanly (fail-safe)"
	)


static func _test_verify_before_mutate(t) -> void:
	var rr := _pipeline_setup()
	var bundle := EQSaveAdapter.save(rr.runtime, rr)
	var fresh := EQReservationRuntime.new()
	fresh.runtime.emit_engine_diagnostics = false
	# handlers NOT registered -> verification fails, nothing applied
	t.ok(
		not EQSaveAdapter.load(fresh.runtime, bundle, {}, fresh),
		"an unregistered effect name fails the load"
	)
	t.eq(
		fresh.runtime.faults.back()["code"], EQError.EFFECT_UNREGISTERED, "...with the stable error"
	)
	t.eq(fresh.runtime.registry.size(), 0, "verify-before-mutate: the runtime was not half-loaded")
	t.eq(fresh.pending_conditional().size(), 0, "no pipeline table was applied")


static func _test_effect_result_binding_verify_before_mutate(t) -> void:
	var original := EQReservationRuntime.new()
	original.runtime.emit_engine_diagnostics = false
	original.runtime.register_actor(&"hero")
	original.runtime.register_effect_commit(
		&"typed", func(_view: Dictionary): return EQEffectCommitResult.make_success([], [])
	)
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.PREPARED
	definition.delay = 5
	definition.effect_name = &"typed"
	var reservation := EQReservation.new(&"hero", definition)
	original.submit(reservation)
	t.eq(reservation.effect_commit_result_version, 1, "typed mode is bound before save")
	var bundle := EQSaveAdapter.save(original.runtime, original)

	var mismatch := EQReservationRuntime.new()
	mismatch.runtime.emit_engine_diagnostics = false
	mismatch.runtime.register_effect(&"typed", func(_view: Dictionary) -> Array: return [])
	var before_scheduler := mismatch.runtime.scheduler.snapshot()
	t.ok(
		not EQSaveAdapter.load(mismatch.runtime, bundle, {}, mismatch),
		"typed save rejects a legacy registry before mutation"
	)
	t.eq(
		mismatch.runtime.faults.back()["code"],
		EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH,
		"load registry swap uses the stable binding mismatch"
	)
	t.eq(
		mismatch.runtime.scheduler.snapshot(),
		before_scheduler,
		"mismatch keeps scheduler untouched"
	)
	t.eq(mismatch.runtime.registry.size(), 0, "mismatch keeps actors unloaded")
	t.eq(mismatch.pending().size(), 0, "mismatch keeps reservation tables unapplied")

	var restored := EQReservationRuntime.new()
	restored.runtime.emit_engine_diagnostics = false
	restored.runtime.register_effect_commit(
		&"typed", func(_view: Dictionary): return EQEffectCommitResult.make_success([], [])
	)
	t.ok(
		EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "matching typed registry loads"
	)
	t.eq(restored.pending().size(), 1, "typed reservation is restored")
	t.eq(
		(restored.pending()[0] as EQReservation).effect_commit_result_version,
		1,
		"restored reservation keeps its typed binding"
	)


static func _test_historical_missing_binding_loads_as_legacy(t) -> void:
	var original := EQReservationRuntime.new()
	original.runtime.emit_engine_diagnostics = false
	original.runtime.register_actor(&"hero")
	original.runtime.register_effect(&"legacy", func(_view: Dictionary) -> Array: return [])
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.PREPARED
	definition.delay = 5
	definition.effect_name = &"legacy"
	original.submit(EQReservation.new(&"hero", definition))
	var current_bundle := EQSaveAdapter.save(original.runtime, original)
	for historical_schema in [1, 2, 3]:
		var bundle: Dictionary = current_bundle.duplicate(true)
		bundle["schema_version"] = historical_schema
		var saved_reservation: Dictionary = bundle["scheduled_reservations"][0]["reservation"]
		saved_reservation.erase("effect_commit_result_version")
		saved_reservation.erase("expiry_effect_commit_result_version")

		var restored := EQReservationRuntime.new()
		restored.runtime.emit_engine_diagnostics = false
		restored.runtime.register_effect(&"legacy", func(_view: Dictionary) -> Array: return [])
		t.ok(
			EQSaveAdapter.load(restored.runtime, bundle, {}, restored),
			"schema %d missing bindings migrate against the legacy registry" % historical_schema
		)
		var restored_reservation := restored.pending()[0] as EQReservation
		t.eq(
			restored_reservation.effect_commit_result_version,
			0,
			"schema %d missing main binding migrates to 0" % historical_schema
		)
		t.eq(
			restored_reservation.expiry_effect_commit_result_version,
			0,
			"schema %d missing expiry binding migrates to 0" % historical_schema
		)


static func _test_historical_schema_rejects_typed_binding(t) -> void:
	var original := EQReservationRuntime.new()
	original.runtime.emit_engine_diagnostics = false
	original.runtime.register_actor(&"hero")
	original.runtime.register_effect_commit(
		&"typed", func(_view: Dictionary): return EQEffectCommitResult.make_success([], [])
	)
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.PREPARED
	definition.delay = 5
	definition.effect_name = &"typed"
	original.submit(EQReservation.new(&"hero", definition))
	var current_bundle := EQSaveAdapter.save(original.runtime, original)

	for historical_schema in [1, 2, 3]:
		var disguised_bundle: Dictionary = current_bundle.duplicate(true)
		disguised_bundle["schema_version"] = historical_schema
		var restored := EQReservationRuntime.new()
		restored.runtime.emit_engine_diagnostics = false
		restored.runtime.register_effect_commit(
			&"typed", func(_view: Dictionary): return EQEffectCommitResult.make_success([], [])
		)
		var before_scheduler := restored.runtime.scheduler.snapshot()
		t.ok(
			not EQSaveAdapter.load(restored.runtime, disguised_bundle, {}, restored),
			"schema %d rejects an explicit typed binding" % historical_schema
		)
		t.eq(
			restored.runtime.faults.back()["code"],
			EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED,
			"schema %d typed downgrade uses the stable version error" % historical_schema
		)
		t.eq(
			restored.runtime.faults.back()["context"]["reason"],
			"binding_not_supported_by_schema",
			"schema %d typed downgrade reports its reason" % historical_schema
		)
		t.eq(
			restored.runtime.scheduler.snapshot(),
			before_scheduler,
			"schema %d typed downgrade is rejected before mutation" % historical_schema
		)
		t.eq(
			restored.runtime.registry.size(),
			0,
			"schema %d typed downgrade leaves actors unloaded" % historical_schema
		)


static func _test_schema_v4_requires_bindings(t) -> void:
	var original := EQReservationRuntime.new()
	original.runtime.emit_engine_diagnostics = false
	original.runtime.register_actor(&"hero")
	original.runtime.register_effect(&"legacy", func(_view: Dictionary) -> Array: return [])
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.PREPARED
	definition.delay = 5
	definition.effect_name = &"legacy"
	original.submit(EQReservation.new(&"hero", definition))
	var bundle := EQSaveAdapter.save(original.runtime, original)
	var saved_reservation: Dictionary = bundle["scheduled_reservations"][0]["reservation"]
	t.ok(saved_reservation.has("effect_commit_result_version"), "v4 writer includes main binding")
	t.ok(
		saved_reservation.has("expiry_effect_commit_result_version"),
		"v4 writer includes expiry binding"
	)
	for missing_key in ["effect_commit_result_version", "expiry_effect_commit_result_version"]:
		var incomplete_bundle: Dictionary = bundle.duplicate(true)
		var scheduled: Array = incomplete_bundle["scheduled_reservations"]
		var incomplete_reservation: Dictionary = scheduled[0]["reservation"]
		incomplete_reservation.erase(missing_key)

		var restored := EQReservationRuntime.new()
		restored.runtime.emit_engine_diagnostics = false
		restored.runtime.register_effect(&"legacy", func(_view: Dictionary) -> Array: return [])
		var before_scheduler := restored.runtime.scheduler.snapshot()
		t.ok(
			not EQSaveAdapter.load(restored.runtime, incomplete_bundle, {}, restored),
			"schema 5 retains the v4 binding requirement for %s" % missing_key
		)
		t.eq(
			restored.runtime.faults.back()["code"],
			EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED,
			"missing %s uses the stable version error" % missing_key
		)
		t.eq(
			restored.runtime.scheduler.snapshot(),
			before_scheduler,
			"missing %s is rejected before mutation" % missing_key
		)
		t.eq(restored.runtime.registry.size(), 0, "missing %s leaves actors unloaded" % missing_key)


static func _test_roundtrip_continuation(t) -> void:
	var original := _pipeline_setup()
	var bundle := EQSaveAdapter.save(original.runtime, original)
	t.ok(not bundle.is_empty(), "setup saves at the boundary")

	var restored := EQReservationRuntime.new()
	restored.runtime.emit_engine_diagnostics = false
	_register_handlers(restored)
	t.ok(
		EQSaveAdapter.load(restored.runtime, bundle, {}, restored),
		"the current bundle loads once handlers are registered"
	)
	t.eq(restored.armed_for(&"hero").size(), 1, "armed reaction survives the roundtrip")
	t.eq(restored.pending_conditional().size(), 1, "condition-gated reservation survives")
	t.eq(
		restored.lines.value_of(&"ct.hero"),
		original.lines.value_of(&"ct.hero"),
		"event-line values survive"
	)

	# continue BOTH sides identically: 20 ticks -> the gated action arms and resolves
	var original_order := _continuation(original)
	var restored_order := _continuation(restored)
	t.eq(
		restored_order,
		original_order,
		"the restored pipeline continues with the identical resolution sequence"
	)
	t.eq(
		restored.last_drained.size(),
		original.last_drained.size(),
		"the declared effect fired identically after the roundtrip"
	)


static func _continuation(rr: EQReservationRuntime) -> Array:
	var order := []
	for _i in 20:
		rr.step_tick()
		var res = rr.resolve_next()
		if res != null:
			order.append([rr.runtime.scheduler.current_tick, res.actor_id])
	return order
