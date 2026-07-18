extends RefCounted
## EQM-141 repair: duplicate arm slots and definition edits must not share or
## rewrite the lifecycle facts captured by each exact engine slot.

const EQReservationRuntime := preload(
	"res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd"
)
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQTriggerEngine := preload(
	"res://addons/event_queue_manager/runtime/eq_trigger_engine.gd"
)
const EQSaveAdapter := preload(
	"res://addons/event_queue_manager/runtime/eq_save_adapter.gd"
)


static func run(t) -> void:
	_test_duplicate_slots_own_independent_rumination(t)
	_test_runtime_duplicate_slots_close_without_gate_leaks(t)
	_test_arm_time_duration_and_rumination_survive_roundtrip(t)


static func _reaction(rumination: int, duration: int = -1) -> EQReservation:
	var definition := EQActionDefinition.new()
	definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	definition.rumination = rumination
	definition.duration = duration
	definition.tags = [&"counter"]
	return EQReservation.new(&"hero", definition)


static func _matcher() -> EQCondition:
	var condition := EQCondition.new()
	condition.match_target = &"hero"
	condition.require_tags = [&"damage"]
	return condition


static func _view() -> Dictionary:
	return {
		"kind": &"hit",
		"source": &"orc",
		"target": &"hero",
		"tags": [&"damage"],
	}


static func _preview_for_slot(previews: Array, slot_id: int) -> Dictionary:
	for preview_value in previews:
		var preview: Dictionary = preview_value
		if int(preview["slot_id"]) == slot_id:
			return preview
	return {}


static func _runtime() -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")
	return rr


static func _count_trace(rr: EQReservationRuntime, kind: String, closed_by: String = "") -> int:
	var count := 0
	for record in rr.runtime.trace().records():
		if String(record.get("kind", "")) != kind:
			continue
		if closed_by != "" and String(record.get("closed_by", "")) != closed_by:
			continue
		count += 1
	return count


static func _test_duplicate_slots_own_independent_rumination(t) -> void:
	var engine := EQTriggerEngine.new()
	var shared := _reaction(1)
	t.ok(engine.arm(shared, _matcher(), 0), "first duplicate slot arms")
	t.ok(engine.arm(shared, _matcher(), 0), "second duplicate slot arms")
	var previews := engine.preview_event_resolved_occurrences(_view(), 0)
	t.eq(previews.size(), 2, "duplicate slots each preview the same event")
	var first_slot := int(previews[0]["slot_id"])
	var second_slot := int(previews[1]["slot_id"])
	t.eq(int(previews[0]["fire_index"]), 1, "first slot starts at FIRE index one")
	t.eq(int(previews[1]["fire_index"]), 1, "second slot starts at FIRE index one")
	t.ok(engine.commit_occurrence(previews[0]), "first slot commits independently")

	previews = engine.preview_event_resolved_occurrences(_view(), 0)
	t.eq(
		int(_preview_for_slot(previews, first_slot)["fire_index"]),
		2,
		"committed slot advances its own FIRE index"
	)
	t.eq(
		int(_preview_for_slot(previews, second_slot)["fire_index"]),
		1,
		"other slot retains its own FIRE index"
	)
	t.ok(
		engine.commit_occurrence(_preview_for_slot(previews, first_slot)),
		"first slot exhausts without closing its duplicate"
	)
	t.eq(engine.armed_count(), 1, "one duplicate slot remains armed")
	t.eq(shared.status, EQReservation.Status.ARMED, "shared compatibility status stays ARMED")
	t.eq(shared.remaining_ruminations, 1, "shared projection reflects the live slot")

	previews = engine.preview_event_resolved_occurrences(_view(), 0)
	t.ok(engine.commit_occurrence(_preview_for_slot(previews, second_slot)), "second slot commits first FIRE")
	previews = engine.preview_event_resolved_occurrences(_view(), 0)
	t.eq(int(previews[0]["fire_index"]), 2, "second slot reaches its own FIRE index two")
	t.ok(engine.commit_occurrence(previews[0]), "second slot exhausts independently")
	t.eq(engine.armed_count(), 0, "both exact slots are closed")
	t.eq(shared.status, EQReservation.Status.RESOLVED, "shared projection closes after last slot")


static func _test_runtime_duplicate_slots_close_without_gate_leaks(t) -> void:
	var rr := _runtime()
	var shared := _reaction(1)
	rr.submit(shared, _matcher())
	rr.submit(shared, _matcher())
	shared.definition.rumination = 20
	rr._sweep_bundle(
		[
			{"event_id": 10, "view_index": 0, "view": _view()},
			{"event_id": 10, "view_index": 1, "view": _view()},
		]
	)
	t.eq(_count_trace(rr, "reaction_fired"), 4, "each slot keeps its arm-time two-FIRE budget")
	t.eq(rr.engine.armed_count(), 0, "both runtime slots close at their own limit")
	t.eq(rr._armed_reaction_gates.size(), 0, "closing duplicate slots leaves no gate state")
	t.eq(rr._armed_gate_watched_counts.size(), 0, "closing duplicate slots leaves no watch state")
	for occurrence in rr.pending():
		t.eq(
			(occurrence as EQReservation).definition.rumination,
			1,
			"scheduled FIRE carries the arm-time rumination snapshot"
		)


static func _test_arm_time_duration_and_rumination_survive_roundtrip(t) -> void:
	var original := _runtime()
	var armed := _reaction(2, 5)
	original.submit(armed, _matcher())
	armed.definition.duration = 99
	armed.definition.rumination = 99
	var bundle := EQSaveAdapter.save(original.runtime, original)
	var armed_row: Dictionary = bundle["armed_triggers"][0]
	var expiry_row: Dictionary = bundle["reaction_expiries"][0]
	t.eq(armed_row["reservation"]["definition"]["duration"], 5, "armed row freezes duration")
	t.eq(armed_row["reservation"]["definition"]["rumination"], 2, "armed row freezes rumination")
	t.eq(armed_row["reservation"]["remaining_ruminations"], 2, "armed row freezes remaining FIREs")
	t.eq(expiry_row["reservation"], armed_row["reservation"], "expiry and arm rows share one slot revision")
	t.eq(bundle["scheduler"]["entries"][0]["due_tick"], 5, "expiry remains at the arm-time tick")

	var restored := EQReservationRuntime.new()
	restored.runtime.emit_engine_diagnostics = false
	t.ok(EQSaveAdapter.load(restored.runtime, bundle, {}, restored), "finite arm snapshot loads")
	var restored_entry: Dictionary = restored.engine.armed_entries()[0]
	t.eq(restored_entry["duration"], 5, "restored engine retains frozen duration")
	t.eq(restored_entry["authored_ruminations"], 2, "restored engine retains authored count")
	var preview: Dictionary = restored.engine.preview_event_resolved_occurrences(_view(), 0)[0]
	t.eq(preview["fire_index"], 1, "restored arm continues at FIRE index one")
	restored._sweep_bundle(
		[{"event_id": 20, "view_index": 0, "view": _view()}]
	)
	t.eq(_count_trace(restored, "reaction_fired"), 1,
		"restored first FIRE commits through the runtime-owned gate pipeline")
	restored.resolve_next()

	var checkpoint := EQSaveAdapter.save(restored.runtime, restored)
	t.eq(checkpoint["armed_triggers"][0]["reservation"]["remaining_ruminations"], 1, "checkpoint stores slot-local remainder")
	var continued := EQReservationRuntime.new()
	continued.runtime.emit_engine_diagnostics = false
	t.ok(EQSaveAdapter.load(continued.runtime, checkpoint, {}, continued), "partial arm checkpoint loads")
	preview = continued.engine.preview_event_resolved_occurrences(_view(), 0)[0]
	t.eq(preview["fire_index"], 2, "roundtrip continuation advances FIRE index exactly once")
	continued.resolve_next()
	t.eq(continued.engine.armed_count(), 0, "arm expires at original finite duration")
	t.eq(_count_trace(continued, "event_invalidated", "duration"), 1, "restored expiry closes by duration")
