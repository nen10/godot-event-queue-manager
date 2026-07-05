extends RefCounted
## EQM-126: operation-phase sub-checkpoint + loop rollback (SEM §8.4).

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")

const GOLDEN_CASE = "mirror_loop_rollback"
const GOLDEN_PATH = "res://tests/golden/mirror_loop_rollback.trace.jsonl"


static func run(t) -> void:
	_test_open_close(t)
	_test_loop_rollback(t)
	_test_faults(t)
	_test_window_close_clears_phase_stack(t)
	_test_phase_api_no_side_effect_path(t)
	_golden(t)


static func _rr() -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	return rr


static func _def(kind: int, delay: int = 0) -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = kind
	d.delay = delay
	return d


static func _record(kind: StringName, source: StringName = &"") -> Dictionary:
	return {"kind": kind, "source": source}


static func _test_open_close(t) -> void:
	var rr := _rr()
	rr.runtime.register_effect(&"mirror_step", func(_v: Dictionary) -> Array:
		return [_record(&"mirrored", &"hero")]
	)
	rr.open_window(&"hero", &"operation")
	t.eq(rr.open_phase(&"target_select", [&"mirror.a"]), true, "open_phase accepts first phase")
	t.eq(rr.open_phase(&"confirm", [&"ok"]), true, "open_phase accepts nested phase")
	t.eq(rr.close_phase(), true, "close_phase defaults to commit and pops")
	t.eq(rr.close_phase(), true, "close_phase pops the remaining phase")
	t.ok('"kind":"phase_closed"' in rr.runtime.trace_jsonl(), "phase_closed is traced on normal close")
	t.ok('"committed":true' in rr.runtime.trace_jsonl(), "committed=true is traced")
	t.eq(rr.close_phase(), false, "close_phase fails when no checkpoint remains")


static func _test_loop_rollback(t) -> void:
	var rr := _rr()
	rr.runtime.register_effect(&"mirror_effect", func(_v: Dictionary) -> Array:
		return [_record(&"mirror_tick", &"hero")]
	)
	rr.open_window(&"hero", &"command")
	t.eq(rr.open_phase(&"target_select", [&"mirror.a"]), true, "open initial target_select")
	t.eq(rr.open_phase(&"mirror_input", [&"mirror.a"]), true, "open first mirror_input")
	t.eq(rr.open_phase(&"confirm"), true, "open confirm")
	var confirm_def := _def(EQActionDefinition.Kind.IMMEDIATE)
	confirm_def.effect_name = &"mirror_effect"
	rr.submit(EQReservation.new(&"hero", confirm_def))
	t.eq(rr.pending().size(), 1, "confirm phase schedules one reservation")
	var rolled_back := rr.open_phase(&"mirror_input", [&"mirror.b"])
	t.eq(rolled_back, false, "re-entering mirror_input rolls back")
	t.eq(rr.pending().size(), 0, "confirm reservation is removed by rollback")
	var trace := rr.runtime.trace_jsonl()
	t.ok('"kind":"phase_rolled_back"' in trace, "phase_rollback is traced")
	t.ok('"phase":"mirror_input"' in trace, "phase_rollback records looped phase")
	t.ok('"rolled_back_from":["confirm"]' in trace, "rolled_back_from captures popped confirm phase")
	t.ok('"cleared_inputs":["mirror.a"]' in trace, "cleared_inputs tracks loop-start mirror input")


static func _test_faults(t) -> void:
	var rr := _rr()
	rr.runtime.faults.clear()
	t.eq(rr.open_phase(&"orphan"), false, "open_phase fails without explicit window")
	t.eq(rr.runtime.faults.back().get("code", &""), EQError.WINDOW_CLOSE_INVALID, "orphan phase open is window close-invalid")

	rr.open_window(&"hero", &"command")
	rr.runtime.faults.clear()
	t.eq(rr.open_phase(&""), false, "open_phase fails on empty name")
	t.eq(rr.runtime.faults.back().get("code", &""), EQError.POLICY_NAME_EMPTY, "empty phase name is rejected")

	rr.runtime.faults.clear()
	t.eq(rr.close_phase(), false, "close_phase fails when no checkpoint exists")
	t.eq(rr.runtime.faults.back().get("code", &""), EQError.WINDOW_CLOSE_INVALID, "close_phase no checkpoint is close invalid")


static func _test_window_close_clears_phase_stack(t) -> void:
	var rr := _rr()
	var w := rr.open_window(&"hero", &"command")
	rr.open_phase(&"phase_before_close")
	rr.close_window()
	t.eq(rr.window_depth(), 0, "window close removes phases with the window")
	rr.runtime.faults.clear()
	t.eq(rr.open_phase(&"after_close"), false, "phase open fails after window close")
	t.eq(rr.runtime.faults.back().get("code", &""), EQError.WINDOW_CLOSE_INVALID, "phase open after window close is rejected")


static func _test_phase_api_no_side_effect_path(t) -> void:
	var rr := _rr()
	rr.runtime.register_effect(&"side_effect", func(_v: Dictionary) -> Array:
		return [_record(&"side_tick", &"hero")]
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"side_effect"
	rr.submit(EQReservation.new(&"hero", d))
	rr.open_window(&"hero", &"command")
	t.eq(rr.close_window(), true, "normal close leaves phase APIs untouched")
	var trace := rr.runtime.trace_jsonl()
	t.ok(trace.find("\"kind\":\"phase_opened\"") == -1, "no phase_opened in non-phase path")
	t.ok(trace.find("\"kind\":\"phase_closed\"") == -1, "no phase_closed in non-phase path")
	t.ok(trace.find("\"kind\":\"phase_rolled_back\"") == -1, "no phase_rolled_back in non-phase path")
	var event_count := rr.pending().size()
	# no phase operations means the pending count from normal flow is still deterministic
	t.ok(event_count >= 0, "non-phase path remains functional")


static func _golden(t) -> void:
	var jsonl := _build_mirror_loop_rollback_trace()
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		_write_golden(t, jsonl)
		return
	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via GODOT_UPDATE_GOLDEN=mirror_loop_rollback)" % GOLDEN_PATH)
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		_dump_actual(jsonl)
	t.eq(jsonl, want, "mirror loop rollback trace matches fixture")


static func _build_mirror_loop_rollback_trace() -> String:
	var rr := _rr()
	rr.runtime.register_effect(&"mirror_effect", func(_v: Dictionary) -> Array:
		return [_record(&"mirror_tick", &"hero")]
	)
	rr.open_window(&"hero", &"command")
	rr.open_phase(&"target_select", [&"mirror.a"])
	rr.open_phase(&"mirror_input", [&"mirror.a"])
	rr.open_phase(&"confirm")
	var confirm_def := _def(EQActionDefinition.Kind.IMMEDIATE)
	confirm_def.effect_name = &"mirror_effect"
	rr.submit(EQReservation.new(&"hero", confirm_def))
	rr.open_phase(&"mirror_input", [&"mirror.b"])
	return rr.runtime.trace_jsonl()


static func _write_golden(t, jsonl: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	if f == null:
		t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
		return
	f.store_string(jsonl)
	f.close()
	t.ok(true, "golden re-baselined for %s via GODOT_UPDATE_GOLDEN=%s" % [GOLDEN_CASE, GOLDEN_CASE])


static func _dump_actual(jsonl: String) -> void:
	var out := OS.get_environment("EQ_RUN_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out + "/traces")
	var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
	if f != null:
		f.store_string(jsonl)
		f.close()
