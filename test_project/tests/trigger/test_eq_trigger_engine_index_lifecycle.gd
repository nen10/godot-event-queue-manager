extends RefCounted
## EQM-136: the production trigger index is transparent across arm ordering,
## mutable condition targets, rumination, duplicate slots, expiry, and disarm.

const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")


static func run(t) -> void:
	_test_target_and_wildcard_keep_global_arm_order(t)
	_test_mutable_target_reindexes_existing_slots(t)
	_test_duplicate_reservation_disarms_first_slot_only(t)
	_test_rumination_survivor_keeps_original_sequence(t)
	_test_expiry_boundary_and_derived_cleanup(t)
	_test_disarm_for_and_public_projection(t)
	_test_invalid_condition_type_does_not_ghost_arm(t)


static func _reaction(
	actor_id: StringName,
	duration: int = EQActionDefinition.DURATION_UNLIMITED,
	rumination: int = 0
) -> EQReservation:
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	definition.duration = duration
	definition.rumination = rumination
	return EQReservation.new(actor_id, definition)


static func _condition(target: StringName) -> EQCondition:
	var condition := EQCondition.new()
	condition.match_target = target
	return condition


static func _view(target: StringName) -> Dictionary:
	return {"kind": &"hit", "source": &"enemy", "target": target, "tags": []}


static func _actor_ids(occurrences: Array) -> Array:
	return occurrences.map(func(occurrence): return occurrence["reservation"].actor_id)


static func _test_invalid_condition_type_does_not_ghost_arm(t) -> void:
	var engine := EQTriggerEngine.new()
	var rejected := _reaction(&"rejected")
	var wrong := EQConditionSpec.new()
	wrong.type = EQConditionSpec.Type.NAMED_PREDICATE
	wrong.predicate_name = &"wrong_layer"
	t.ok(not engine.arm(rejected, wrong, 0), "engine directly rejects a non-EQCondition")
	t.eq(rejected.status, EQReservation.Status.PENDING, "direct rejection leaves status unchanged")
	t.eq(engine.armed_count(), 0, "direct rejection creates no canonical arm")

	var accepted := _reaction(&"accepted")
	t.ok(engine.arm(accepted, _condition(&"hero"), 0), "a valid arm still succeeds")
	t.eq(engine.armed_count(), 1, "the valid arm is the first and only slot")


static func _test_target_and_wildcard_keep_global_arm_order(t) -> void:
	var engine := EQTriggerEngine.new()
	engine.arm(_reaction(&"target-first"), _condition(&"hero"), 0)
	engine.arm(_reaction(&"wildcard"), _condition(&""), 0)
	engine.arm(_reaction(&"other-target"), _condition(&"other"), 0)
	engine.arm(_reaction(&"target-last"), _condition(&"hero"), 0)

	var fired := engine.on_event_resolved_occurrences(_view(&"hero"), 1)
	t.eq(
		_actor_ids(fired),
		[&"target-first", &"wildcard", &"target-last"],
		"target bucket and wildcard candidates retain global arm order"
	)
	t.eq(engine.armed_count(), 1, "non-candidate target remains armed")
	t.eq(engine.armed_entries()[0]["owner"], &"other-target", "the other target slot survives")


static func _test_mutable_target_reindexes_existing_slots(t) -> void:
	var engine := EQTriggerEngine.new()
	var condition := _condition(&"old-target")
	engine.arm(_reaction(&"retargeted-first"), condition, 0)
	engine.arm(_reaction(&"retargeted-second"), condition, 0)
	condition.match_target = &"new-target"

	t.eq(engine.on_event_resolved(_view(&"old-target"), 1).size(), 0, "old bucket no longer sees the slot")
	t.eq(
		engine.on_event_resolved(_view(&"new-target"), 1).map(func(reservation): return reservation.actor_id),
		[&"retargeted-first", &"retargeted-second"],
		"new bucket sees every slot sharing the changed condition in arm order"
	)

	var wildcard_condition := _condition(&"specific")
	engine.arm(_reaction(&"became-wildcard"), wildcard_condition, 2)
	wildcard_condition.match_target = &""
	t.eq(
		engine.on_event_resolved(_view(&"unrelated"), 2).size(),
		1,
		"retargeting to wildcard makes the existing slot target-agnostic"
	)


static func _test_duplicate_reservation_disarms_first_slot_only(t) -> void:
	var engine := EQTriggerEngine.new()
	var reservation := _reaction(&"duplicate")
	var condition := _condition(&"hero")
	engine.arm(reservation, condition, 0)
	engine.arm(reservation, condition, 0)

	t.ok(engine.disarm(reservation), "disarm finds the first duplicate arm slot")
	t.eq(engine.armed_count(), 1, "only one duplicate slot is removed")
	t.eq(engine.on_event_resolved(_view(&"hero"), 1).size(), 1, "the second duplicate slot remains indexed")
	t.eq(engine.armed_count(), 0, "the remaining slot closes normally")


static func _test_rumination_survivor_keeps_original_sequence(t) -> void:
	var engine := EQTriggerEngine.new()
	engine.arm(_reaction(&"old-ruminating", -1, 1), _condition(&"hero"), 0)
	engine.arm(_reaction(&"middle-once"), _condition(&"hero"), 0)

	var first := engine.on_event_resolved_occurrences(_view(&"hero"), 1)
	t.eq(_actor_ids(first), [&"old-ruminating", &"middle-once"], "first sweep follows arm order")
	t.eq(engine.armed_count(), 1, "rumination survivor remains armed")

	engine.arm(_reaction(&"new-last"), _condition(&"hero"), 1)
	var second := engine.on_event_resolved_occurrences(_view(&"hero"), 2)
	t.eq(
		_actor_ids(second),
		[&"old-ruminating", &"new-last"],
		"rumination survivor keeps its original sequence ahead of a later arm"
	)
	t.eq(first[0]["fire_index"], 1, "first rumination occurrence keeps fire index 1")
	t.eq(second[0]["fire_index"], 2, "second rumination occurrence keeps fire index 2")


static func _test_expiry_boundary_and_derived_cleanup(t) -> void:
	var engine := EQTriggerEngine.new()
	var expiring := _reaction(&"finite", 5)
	engine.arm(expiring, _condition(&"hero"), 0)

	t.eq(engine.on_event_resolved(_view(&"other"), 5).size(), 0, "deadline tick remains inside the reaction window")
	t.eq(engine.armed_count(), 1, "finite arm survives at its exact end tick")
	t.eq(engine.on_event_resolved(_view(&"hero"), 6).size(), 0, "deadline plus one expires before matching")
	t.eq(engine.armed_count(), 0, "expired slot leaves the canonical table")
	t.eq(engine.expired.size(), 1, "expiry remains observable")
	t.eq(expiring.status, EQReservation.Status.INVALIDATED, "expiry status remains INVALIDATED")

	var staggered := EQTriggerEngine.new()
	staggered.arm(_reaction(&"early", 5), _condition(&"hero"), 0)
	staggered.arm(_reaction(&"late", 10), _condition(&"hero"), 0)
	staggered.on_event_resolved(_view(&"other"), 6)
	t.eq(staggered.armed_count(), 1, "crossing the first deadline keeps the later finite arm")
	t.eq(staggered.expired[0]["reservation"].actor_id, &"early", "expiry scan preserves canonical arm order")
	staggered.on_event_resolved(_view(&"other"), 10)
	t.eq(staggered.armed_count(), 1, "recomputed minimum retains the later arm at its boundary")
	t.eq(staggered.on_event_resolved(_view(&"hero"), 11).size(), 0, "later arm expires before a post-boundary match")
	t.eq(staggered.expired.size(), 2, "minimum expiry cache advances across staggered deadlines")


static func _test_disarm_for_and_public_projection(t) -> void:
	var engine := EQTriggerEngine.new()
	engine.arm(_reaction(&"departing"), _condition(&"hero"), 0)
	engine.arm(_reaction(&"staying"), _condition(&"hero"), 0)

	var removed := engine.disarm_for(&"departing")
	t.eq(removed.size(), 1, "actor disarm removes its indexed arm slots")
	var entries := engine.armed_entries()
	t.eq(entries.size(), 1, "one public armed entry remains")
	t.ok(not entries[0].has("_index_sequence"), "public serialization projection hides index sequence")
	t.ok(not entries[0].has("_expiry_end_tick"), "public serialization projection hides expiry cache")
	t.eq(engine.on_event_resolved(_view(&"hero"), 1)[0].actor_id, &"staying", "remaining actor still fires")
