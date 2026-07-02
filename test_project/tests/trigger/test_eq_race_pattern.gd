extends RefCounted
## EQM-116: the OR-resolution race pattern (SEM §5.2, Q18/Q28) — one effect,
## several racing events; first resolution wins, losers sweep with
## closed_by: race_lost; deterministic race ids; all candidates visible in the
## trace; the overlay aggregates candidates (game-dev debug).

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQDebugOverlay := preload("res://addons/event_queue_manager/runtime/ui/eq_debug_overlay.gd")


static func run(t) -> void:
	_test_first_condition_wins(t)
	_test_simultaneous_uses_issuance_order(t)
	_test_deterministic_ids_and_replay(t)
	_test_overlay_aggregates_candidates(t)


static func _member(rr: EQReservationRuntime, actor: StringName, line: StringName, threshold: int) -> EQReservation:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.IMMEDIATE
	d.effect_name = &"burst"
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.LINE_THRESHOLD
	spec.line_id = line
	spec.threshold = threshold
	d.solve_conditions = [spec]
	return EQReservation.new(actor, d)


static func _race_rr(rate_a: int, rate_b: int) -> Array:  # [rr, resA, resB, effects]
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.lines.issue(&"line_a", 0, rate_a)
	rr.lines.issue(&"line_b", 0, rate_b)
	var effects := []
	rr.runtime.register_effect(&"burst", func(_v) -> Array:
		var rec := EQEffectRecord.new()
		rec.kind = &"burst"
		effects.append(rec)
		return [rec])
	var a := _member(rr, &"hero", &"line_a", 10)
	var b := _member(rr, &"hero", &"line_b", 10)
	rr.submit_race([a, b])
	return [rr, a, b, effects]


static func _run_ticks(rr: EQReservationRuntime, ticks: int) -> int:
	var resolved := 0
	for _i in ticks:
		rr.step_tick()
		while rr.resolve_next() != null:
			resolved += 1
	return resolved


static func _test_first_condition_wins(t) -> void:
	var s := _race_rr(5, 1)  # line_a reaches 10 at tick 2; line_b would need tick 10
	var rr: EQReservationRuntime = s[0]
	var resolved := _run_ticks(rr, 4)
	t.eq(resolved, 1, "exactly one racing member resolves")
	t.eq((s[1] as EQReservation).status, EQReservation.Status.RESOLVED, "the member whose condition held first won")
	t.eq((s[2] as EQReservation).status, EQReservation.Status.INVALIDATED, "the loser was swept")
	t.eq((s[3] as Array).size(), 1, "the shared effect applied exactly once")
	var jsonl := rr.runtime.trace_jsonl()
	t.ok('"kind":"race_opened"' in jsonl and '"members":2' in jsonl, "race opening is traced (all candidates visible — EQM debug)")
	t.ok('"kind":"race_resolved"' in jsonl and '"race_group":"eqm.race.1"' in jsonl, "settlement is traced with the group id")
	t.ok('"closed_by":"race_lost"' in jsonl and '"race_group":"eqm.race.1"' in jsonl, "the loser's invalidation names the race")

	var more := _run_ticks(rr, 10)
	t.eq(more, 0, "nothing else resolves after the race settled (loser fully cancelled)")


static func _test_simultaneous_uses_issuance_order(t) -> void:
	var s := _race_rr(5, 5)  # both reach 10 at tick 2 together
	var rr: EQReservationRuntime = s[0]
	var resolved := _run_ticks(rr, 4)
	t.eq(resolved, 1, "simultaneous arrival still yields exactly one winner")
	t.eq((s[1] as EQReservation).status, EQReservation.Status.RESOLVED, "the winner is the first-issued member (fallback = issuance order, no race-specific rule)")
	t.eq((s[2] as EQReservation).status, EQReservation.Status.INVALIDATED, "the simultaneously-arrived loser was cancelled before resolving")
	t.eq((s[3] as Array).size(), 1, "one effect even when both were pushed in the same sweep")


static func _test_deterministic_ids_and_replay(t) -> void:
	var s1 := _race_rr(5, 1)
	_run_ticks(s1[0], 4)
	var s2 := _race_rr(5, 1)
	_run_ticks(s2[0], 4)
	t.eq((s1[0] as EQReservationRuntime).runtime.trace_jsonl(), (s2[0] as EQReservationRuntime).runtime.trace_jsonl(), "identical input replays byte-identically (deterministic gid + settlement)")


static func _test_overlay_aggregates_candidates(t) -> void:
	var overlay := EQDebugOverlay.new()
	overlay.set_state(
		[&"hero", &"hero", &"orc"],
		[
			{"decided_by": "tick", "race_group": "eqm.race.1"},
			{"decided_by": "tick", "race_group": "eqm.race.1"},
			{"decided_by": "priority"},
		])
	t.eq(overlay.group_rows().size(), 1, "consecutive race candidates aggregate into one group row (game-dev debug)")
	t.eq(overlay.rows().size(), 1, "non-race entries keep their normal rows")
	var label: Label = overlay.group_rows()[0].get_child(1)
	t.ok("2 candidates" in label.text, "the group row shows the candidate count, not two effect rows")
	overlay.free()
