extends RefCounted
## EQM-125 / SEM §8.2-§8.3: intervention close with meta-levels and
## explicit-window pending-membership bookkeeping.

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition = preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQEffectRecord = preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQWindow := preload("res://addons/event_queue_manager/runtime/eq_window.gd")

const GOLDEN_CASE = "interception_close"
const GOLDEN_PATH = "res://tests/golden/interception_close.trace.jsonl"


static func run(t) -> void:
	_test_equal_meta_success(t)
	_test_meta_short_avoids(t)
	_test_nested_close(t)
	_test_target_members_cleanup_only(t)
	_test_no_intervention_path_still_unchanged(t)
	_golden(t)


static func _rr(actors: Array) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for a in actors:
		rr.runtime.register_actor(a)
	return rr


static func _def(kind: int, delay: int = 0) -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = kind
	d.delay = delay
	return d


static func _record(kind: StringName, source: StringName = &"") -> EQEffectRecord:
	var r := EQEffectRecord.new()
	r.kind = kind
	r.source = source
	return r


static func _pending_actors(rr: EQReservationRuntime) -> Array[StringName]:
	var out: Array[StringName] = []
	for r in rr.pending():
		out.append((r as EQReservation).actor_id)
	return out


static func _test_equal_meta_success(t) -> void:
	var rr := _rr([&"mover"])
	rr.runtime.register_effect(&"step2", func(_v: Dictionary) -> Array:
		return [_record(&"move_step", &"mover")]
	)
	rr.runtime.register_effect(&"step3", func(_v: Dictionary) -> Array:
		return [_record(&"move_step", &"mover")]
	)
	var w := rr.open_window(&"mover", &"command", EQWindow.DEADLINE_UNLIMITED, 0, &"", 1)
	var d2 := _def(EQActionDefinition.Kind.IMMEDIATE)
	d2.effect_name = &"step2"
	var d3 := _def(EQActionDefinition.Kind.PREPARED, 3)
	d3.effect_name = &"step3"
	rr.submit(EQReservation.new(&"mover", d2))
	rr.submit(EQReservation.new(&"mover", d3))
	var first := rr.resolve_next()
	t.ok(first != null and first.actor_id == &"mover", "the immediate 2-step event resolves before intervention")
	var ok := rr.intervene_close(w.window_id, {"meta_level": 1, "event_id": 77, "actor": &"interceptor"})
	t.eq(ok, true, "intervention succeeds when meta is equal")
	t.eq(rr.pending().size(), 0, "intervention cancels pending window members")
	var trace := rr.runtime.trace_jsonl()
	t.ok('"kind":"window_closed"' in trace and '"cause":"intervention"' in trace, "window_closed carries intervention cause")
	t.ok('"window_meta":1' in trace and '"intervener_meta":1' in trace, "window_closed carries intervention metas")
	t.ok('"intervener_event_id":77' in trace, "intervention event id is traced when supplied")
	t.ok('"closed_by":"intervention"' in trace, "window-member invalidation is traced as closed_by intervention")


static func _test_meta_short_avoids(t) -> void:
	var rr := _rr([&"mover"])
	rr.runtime.register_effect(&"step3", func(_v: Dictionary) -> Array:
		return [_record(&"move_step", &"mover")]
	)
	var w := rr.open_window(&"mover", &"command", EQWindow.DEADLINE_UNLIMITED, 0, &"", 2)
	var d := _def(EQActionDefinition.Kind.PREPARED, 3)
	d.effect_name = &"step3"
	rr.submit(EQReservation.new(&"mover", d))
	var ok := rr.intervene_close(w.window_id, {"meta_level": 1, "event_id": 88})
	t.eq(ok, false, "intervention is avoided when meta is short")
	t.eq(rr.pending().size(), 1, "pending window members are kept when avoided")
	t.eq(rr.window_depth(), 1, "the target window stays open on avoid")
	var trace := rr.runtime.trace_jsonl()
	t.ok('"kind":"intervention_avoided"' in trace, "intervention_avoided is traced on meta miss")
	t.ok('"intervener_meta":1' in trace, "intervention_avoided includes intervener_meta")
	t.ok('"window_meta":2' in trace, "intervention_avoided includes target window_meta")


static func _test_nested_close(t) -> void:
	var rr := _rr([&"mover"])
	var outer := rr.open_window(&"mover", &"outer", EQWindow.DEADLINE_UNLIMITED, 0, &"", 1)
	var inner := rr.open_window(&"mover", &"inner", EQWindow.DEADLINE_UNLIMITED, 0, &"", 1)
	rr.runtime.register_effect(&"noop", func(_v: Dictionary) -> Array:
		return []
	)
	var d := _def(EQActionDefinition.Kind.PREPARED, 4)
	d.effect_name = &"noop"
	var pending_id := rr.submit(EQReservation.new(&"mover", d))
	t.eq(inner.nest_level, 2, "nested window was opened")
	t.eq(pending_id > 0, true, "pending member in nested window is tracked")
	var ok := rr.intervene_close(outer.window_id, {"meta_level": 1, "event_id": 12})
	t.eq(ok, true, "intervening outer window also closes nested inner window")
	t.eq(rr.window_depth(), 0, "both nested explicit windows are gone after intervention")
	t.eq(rr.pending().size(), 0, "nested window pending members are cancelled")
	var closes := 0
	for line in rr.runtime.trace_jsonl().split("\n"):
		if line.contains('"kind":"window_closed"'):
			closes += 1
	if closes < 2:
		t.ok(false, "intervention closes nested windows too (found %d window_closed" % closes)

static func _test_target_members_cleanup_only(t) -> void:
	var rr := _rr([&"mover", &"watcher"])
	rr.runtime.register_effect(&"outside", func(_v: Dictionary) -> Array:
		return [_record(&"outside_step", &"watcher")]
	)
	rr.runtime.register_effect(&"inside", func(_v: Dictionary) -> Array:
		return [_record(&"inside_step", &"mover")]
	)
	var outside := _def(EQActionDefinition.Kind.PREPARED, 4)
	outside.effect_name = &"outside"
	var outside_id := rr.submit(EQReservation.new(&"watcher", outside))
	t.ok(outside_id > 0, "baseline pending outside window exists")
	var w := rr.open_window(&"mover", &"command", EQWindow.DEADLINE_UNLIMITED, 0, &"", 1)
	var inside := _def(EQActionDefinition.Kind.PREPARED, 3)
	inside.effect_name = &"inside"
	rr.submit(EQReservation.new(&"mover", inside))
	rr.intervene_close(w.window_id, {"meta_level": 1})
	var actors := _pending_actors(rr)
	t.ok(actors.has(&"watcher"), "non-owned pending reservation survives intervention")
	t.ok(not actors.has(&"mover"), "owned pending reservation is purged by intervention")
	t.ok(rr.pending().size() >= 1, "outside pending event remains in scheduler")


static func _test_no_intervention_path_still_unchanged(t) -> void:
	var rr := _rr([&"mover"])
	rr.runtime.register_effect(&"walk", func(_v: Dictionary) -> Array:
		return [_record(&"walk_step", &"mover")]
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"walk"
	t.ok(rr.submit(EQReservation.new(&"mover", d)) > 0, "submit works on normal path")
	var w := rr.open_window(&"mover", &"command", EQWindow.DEADLINE_UNLIMITED, 0, &"", 0)
	t.ok(rr.close_window(), "close_window still works with intervention feature untouched")
	var trace := rr.runtime.trace_jsonl()
	t.ok(trace.find("intervention") == -1, "no intervention trace is emitted by normal close")
	t.eq(rr.pending().size(), 1, "normal close does not flush normal pending events")


static func _golden(t) -> void:
	var jsonl := _build_interception_close_trace()
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		_write_golden(t, jsonl)
		return
	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via ./tools/test.sh --update-golden interception_close)" % GOLDEN_PATH)
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		_dump_actual(jsonl)
	t.eq(jsonl, want, "interception close trace matches fixture")


## The frozen acceptance narrative (EBS 相談1/Q50): a 5-step move window is
## intercepted after step 2 — the 2 resolved steps stay, the pending 3 are
## swept, tie meta (1 vs 1) means the interception succeeds.
static func _build_interception_close_trace() -> String:
	var rr := _rr([&"mover"])
	rr.runtime.register_effect(&"move_step", func(_v: Dictionary) -> Array:
		return [_record(&"move_step", &"mover")]
	)
	var w := rr.open_window(&"mover", &"move", EQWindow.DEADLINE_UNLIMITED, 0, &"", 1)
	for i in range(2):
		var d := _def(EQActionDefinition.Kind.IMMEDIATE)
		d.effect_name = &"move_step"
		rr.submit(EQReservation.new(&"mover", d))
	for i in range(3):
		var d := _def(EQActionDefinition.Kind.PREPARED, 2 + i)
		d.effect_name = &"move_step"
		rr.submit(EQReservation.new(&"mover", d))
	rr.resolve_next()
	rr.resolve_next()
	rr.intervene_close(w.window_id, {"meta_level": 1, "event_id": 100})
	return rr.runtime.trace_jsonl()


static func _write_golden(t, jsonl: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	if f == null:
		t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
		return
	f.store_string(jsonl)
	f.close()
	t.ok(true, "golden re-baselined for %s via ./tools/test.sh --update-golden %s" % [GOLDEN_CASE, GOLDEN_CASE])


static func _dump_actual(jsonl: String) -> void:
	var out := OS.get_environment("EQ_RUN_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out + "/traces")
	var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
	if f != null:
		f.store_string(jsonl)
		f.close()
