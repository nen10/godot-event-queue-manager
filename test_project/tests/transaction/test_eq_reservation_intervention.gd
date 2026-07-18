extends RefCounted
## EQM-135: issuance-time meta intervention against one ordinary scheduled
## PREPARED reservation, with fail-closed group/context boundaries.

const EQReservationRuntime := preload(
	"res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd"
)
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQCondition := preload(
	"res://addons/event_queue_manager/resources/eq_condition.gd"
)
const EQEffectCommitResult := preload(
	"res://addons/event_queue_manager/runtime/eq_effect_commit_result.gd"
)
const EQSaveAdapter := preload(
	"res://addons/event_queue_manager/runtime/eq_save_adapter.gd"
)
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_equal_meta_cancels_without_effect(t)
	_test_lower_meta_avoids_without_mutation(t)
	_test_issued_meta_roundtrips(t)
	_test_invalid_target_rejections(t)
	_test_group_and_fire_rejections(t)


static func _rr(actors: Array = [&"target"]) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for actor in actors:
		rr.runtime.register_actor(actor)
	return rr


static func _definition(
	kind: int,
	meta_level: int = 0,
	delay: int = 4,
	effect_name: StringName = &""
) -> EQActionDefinition:
	var definition := EQActionDefinition.new()
	definition.kind = kind
	definition.delay = delay if kind == EQActionDefinition.Kind.PREPARED else 0
	definition.meta_level = meta_level
	definition.effect_name = effect_name
	return definition


static func _saved_scheduled_row(bundle: Dictionary, event_id: int) -> Dictionary:
	for row in bundle.get("scheduled_reservations", []):
		if int(row.get("event_id", -1)) == event_id:
			return row
	return {}


static func _test_equal_meta_cancels_without_effect(t) -> void:
	var rr := _rr([&"target", &"other"])
	var effects := {"target": 0, "other": 0}
	rr.runtime.register_effect(&"target_effect", func(_view: Dictionary) -> Array:
		effects["target"] += 1
		return []
	)
	rr.runtime.register_effect(&"other_effect", func(_view: Dictionary) -> Array:
		effects["other"] += 1
		return []
	)
	var target := EQReservation.new(
		&"target", _definition(EQActionDefinition.Kind.PREPARED, 2, 4, &"target_effect")
	)
	var target_id := rr.submit(target)
	var other_id := rr.submit(
		EQReservation.new(
			&"other", _definition(EQActionDefinition.Kind.PREPARED, 0, 5, &"other_effect")
		)
	)
	t.ok(target_id > 0 and other_id > target_id, "ordinary prepared reservations are scheduled")

	var succeeded := rr.intervene_reservation(
		target_id, {"meta_level": 2, "event_id": 91}
	)
	t.ok(succeeded, "equal issuance meta succeeds")
	t.eq(target.status, EQReservation.Status.INVALIDATED, "successful intervention invalidates target")
	t.eq(rr.runtime.scheduler.size(), 1, "only the target scheduler event is cancelled")
	t.eq(rr.pending().size(), 1, "target disappears from pending reservations")
	t.eq(effects["target"], 0, "intervened target effect is not executed")
	t.ok(
		_saved_scheduled_row(EQSaveAdapter.save(rr.runtime, rr), target_id).is_empty(),
		"intervened target disappears from the save table"
	)

	var records := rr.runtime.trace().records()
	t.eq(records.size(), 1, "successful intervention emits exactly one immediate result record")
	var closed: Dictionary = records[0]
	t.eq(closed["kind"], "event_invalidated", "success reuses the invalidation trace kind")
	t.eq(closed["closed_by"], "intervention", "success carries the intervention cause")
	t.eq(closed["event_id"], target_id, "success identifies the target event")
	t.eq(closed["reservation_meta"], 2, "success explains target issuance meta")
	t.eq(closed["intervener_meta"], 2, "success explains intervener meta")
	t.eq(closed["intervener_event_id"], 91, "success identifies the intervener event")

	rr.resolve_next()
	t.eq(effects["target"], 0, "later resolution cannot execute the cancelled effect")
	t.eq(effects["other"], 1, "unrelated scheduled work still resolves")
	var after := rr.runtime.trace().records()
	t.eq(after[0]["kind"], "event_invalidated", "intervention record stays before later resolution")
	t.eq(after[1]["kind"], "resolved", "later scheduler resolution follows the intervention")


static func _test_lower_meta_avoids_without_mutation(t) -> void:
	var rr := _rr()
	var effects: Array = []
	rr.runtime.register_effect(&"prepared_effect", func(_view: Dictionary) -> Array:
		effects.append(&"ran")
		return []
	)
	var target := EQReservation.new(
		&"target", _definition(EQActionDefinition.Kind.PREPARED, 3, 4, &"prepared_effect")
	)
	var event_id := rr.submit(target)
	var scheduler_before := rr.runtime.scheduler.snapshot()
	var state_before := rr.save_state()

	t.ok(
		not rr.intervene_reservation(event_id, {"meta_level": 2, "event_id": 92}),
		"lower meta is avoided"
	)
	t.eq(rr.runtime.faults.size(), 0, "an avoided intervention is normal gameplay, not a fault")
	t.eq(rr.runtime.scheduler.snapshot(), scheduler_before, "avoid leaves scheduler state byte-equivalent")
	t.eq(rr.save_state(), state_before, "avoid leaves the reservation save state unchanged")
	t.eq(target.status, EQReservation.Status.PENDING, "avoid leaves target pending")
	var avoided: Dictionary = rr.runtime.trace().records()[0]
	t.eq(avoided["kind"], "intervention_avoided", "avoid has its own observable result")
	t.eq(avoided["reservation_meta"], 3, "avoid explains target meta")
	t.eq(avoided["intervener_meta"], 2, "avoid explains intervener meta")

	rr.resolve_next()
	t.eq(effects.size(), 1, "avoided target later executes normally")


static func _test_issued_meta_roundtrips(t) -> void:
	var original := _rr()
	original.runtime.register_effect(&"prepared_effect", func(_view: Dictionary) -> Array: return [])
	var definition := _definition(
		EQActionDefinition.Kind.PREPARED, 2, 4, &"prepared_effect"
	)
	var target := EQReservation.new(&"target", definition)
	var event_id := original.submit(target)
	definition.meta_level = 9
	var bundle := EQSaveAdapter.save(original.runtime, original)
	t.eq(bundle["schema_version"], 8, "issuance meta remains present in save schema v8")
	var saved := _saved_scheduled_row(bundle, event_id)
	t.eq(saved["reservation"]["issued_meta_level"], 2, "save retains the sampled issuance meta")
	t.eq(saved["reservation"]["definition"]["meta_level"], 9, "later definition value remains distinct")

	var restored := EQReservationRuntime.new()
	restored.runtime.emit_engine_diagnostics = false
	restored.runtime.register_effect(&"prepared_effect", func(_view: Dictionary) -> Array: return [])
	t.ok(
		EQSaveAdapter.load(restored.runtime, bundle, {}, restored),
		"schema v7 issued meta roundtrips"
	)
	t.ok(
		restored.intervene_reservation(event_id, {"meta_level": 3}),
		"greater meta succeeds against issuance meta rather than the later definition value"
	)

	var missing: Dictionary = bundle.duplicate(true)
	_saved_scheduled_row(missing, event_id)["reservation"].erase("issued_meta_level")
	var missing_target := EQReservationRuntime.new()
	missing_target.runtime.emit_engine_diagnostics = false
	missing_target.runtime.register_effect(&"prepared_effect", func(_view: Dictionary) -> Array: return [])
	t.ok(
		not EQSaveAdapter.load(missing_target.runtime, missing, {}, missing_target),
		"schema v7 rejects a missing issuance sample before mutation"
	)
	t.eq(
		missing_target.runtime.faults.back()["code"],
		EQError.RESERVATION_ISSUED_META_LEVEL_INVALID,
		"missing issuance sample uses the stable schema error"
	)

	var historical: Dictionary = bundle.duplicate(true)
	historical["schema_version"] = 6
	_saved_scheduled_row(historical, event_id)["reservation"].erase("issued_meta_level")
	var historical_target := EQReservationRuntime.new()
	historical_target.runtime.emit_engine_diagnostics = false
	historical_target.runtime.register_effect(
		&"prepared_effect", func(_view: Dictionary) -> Array: return []
	)
	t.ok(
		EQSaveAdapter.load(historical_target.runtime, historical, {}, historical_target),
		"historical schema v6 migrates a missing sample from inline definition meta"
	)
	t.ok(
		historical_target.intervene_reservation(event_id, {"meta_level": 9}),
		"the migrated historical sample uses its representable definition value"
	)

	var disguised: Dictionary = bundle.duplicate(true)
	disguised["schema_version"] = 6
	var disguised_target := EQReservationRuntime.new()
	disguised_target.runtime.emit_engine_diagnostics = false
	disguised_target.runtime.register_effect(&"prepared_effect", func(_view: Dictionary) -> Array: return [])
	t.ok(
		not EQSaveAdapter.load(disguised_target.runtime, disguised, {}, disguised_target),
		"a differing issuance sample cannot be disguised as historical schema v6"
	)
	t.eq(
		disguised_target.runtime.faults.back()["context"]["reason"],
		"field_not_supported_by_schema",
		"historical-schema rejection explains the incompatibility"
	)


static func _assert_rejected(
	t, rr: EQReservationRuntime, event_id: int, reason: String, label: String
) -> void:
	var scheduler_before := rr.runtime.scheduler.snapshot()
	var state_before := rr.save_state()
	t.ok(
		not rr.intervene_reservation(event_id, {"meta_level": 99}),
		"%s is rejected" % label
	)
	t.eq(
		rr.runtime.faults.back()["code"],
		EQError.RESERVATION_INTERVENTION_INVALID,
		"%s uses the stable intervention error" % label
	)
	t.eq(
		rr.runtime.faults.back()["context"]["reason"],
		reason,
		"%s reports its rejection reason" % label
	)
	t.eq(rr.runtime.scheduler.snapshot(), scheduler_before, "%s leaves scheduler unchanged" % label)
	t.eq(rr.save_state(), state_before, "%s leaves reservation state unchanged" % label)


static func _test_invalid_target_rejections(t) -> void:
	var missing := _rr()
	_assert_rejected(t, missing, 404, "missing", "unknown event id")

	var immediate := _rr()
	var immediate_id := immediate.submit(
		EQReservation.new(&"target", _definition(EQActionDefinition.Kind.IMMEDIATE))
	)
	_assert_rejected(t, immediate, immediate_id, "wrong_kind", "non-PREPARED reservation")


static func _test_group_and_fire_rejections(t) -> void:
	var bundled := _rr()
	var bundled_reservation := EQReservation.new(
		&"target", _definition(EQActionDefinition.Kind.PREPARED, 0, 1)
	)
	t.ok(
		bundled.submit_bundle([bundled_reservation], 4) != &"",
		"bundle setup succeeds"
	)
	_assert_rejected(t, bundled, bundled_reservation.event_id, "bundle", "bundle member")

	var raced := _rr()
	var race_a := EQReservation.new(
		&"target", _definition(EQActionDefinition.Kind.PREPARED, 0, 3)
	)
	var race_b := EQReservation.new(
		&"target", _definition(EQActionDefinition.Kind.PREPARED, 0, 4)
	)
	raced.submit_race([race_a, race_b])
	_assert_rejected(t, raced, race_a.event_id, "race", "race member")

	var fired := _rr([&"target", &"source"])
	fired.runtime.register_effect(&"counter", func(_view: Dictionary) -> Array: return [])
	fired.runtime.register_effect_commit(
		&"emit",
		func(_view: Dictionary):
			return EQEffectCommitResult.make_success(
				[],
				[{
					"kind": &"effect_fact",
					"source": &"source",
					"target": &"target",
					"tags": [&"damage"],
				}]
		)
	)
	var reaction_definition := EQActionDefinition.new()
	reaction_definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	reaction_definition.duration = EQActionDefinition.DURATION_UNLIMITED
	reaction_definition.effect_name = &"counter"
	var condition := EQCondition.new()
	condition.match_target = &"target"
	condition.require_tags = [&"damage"]
	fired.submit(EQReservation.new(&"target", reaction_definition), condition)
	var emitter_definition := _definition(EQActionDefinition.Kind.IMMEDIATE, 0, 0, &"emit")
	fired.submit(EQReservation.new(&"source", emitter_definition))
	fired.resolve_next()
	var fire: EQReservation = fired.pending()[0]
	t.ok(
		not fired.reaction_fire_context_for_event(fire.event_id).is_empty(),
		"reaction FIRE setup carries its occurrence context"
	)
	_assert_rejected(t, fired, fire.event_id, "reaction_fire", "reaction FIRE occurrence")
