extends RefCounted
## EQM-124: atomic bundle processing — multiple same-tick members resolve as one
## deterministic unit with a single sweep and a single chunk drain.

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation = preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition = preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQEffectRecord = preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQConditionSpec = preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQCondition = preload("res://addons/event_queue_manager/resources/eq_condition.gd")

const GOLDEN_CASE = "fairness_bundle"
const GOLDEN_PATH = "res://tests/golden/fairness_bundle.trace.jsonl"


static func run(t) -> void:
	_test_bundle_members_and_reaction_boundaries(t)
	_test_bundle_member_lazy_invalidation(t)
	_test_bundle_reject_invalid_inputs(t)
	_test_non_bundle_resolve_path_unchanged(t)
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


static func _record(kind: StringName, target: StringName = &"") -> EQEffectRecord:
	var r := EQEffectRecord.new()
	r.kind = kind
	r.target = target
	return r


static func _line_spec(line: StringName, threshold: int, cmp: int = EQConditionSpec.Comparison.LE) -> EQConditionSpec:
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.LINE_THRESHOLD
	spec.line_id = line
	spec.threshold = threshold
	spec.comparison = cmp
	return spec


static func _line_index(lines: PackedStringArray, needle: String) -> int:
	for i in range(lines.size()):
		if lines[i].contains(needle):
			return i
	return -1


static func _test_bundle_members_and_reaction_boundaries(t) -> void:
	var rr := _rr([&"x", &"y"])
	var seen: Array[StringName] = []
	rr.runtime.register_effect(&"bundle_hit", func(view: Dictionary) -> Array:
		var rec := _record(&"bundle_hit")
		rec.source = StringName(view["source"])
		seen.append(rec.source)
		return [rec]
	)
	var at := _def(EQActionDefinition.Kind.IMMEDIATE)
	at.effect_name = &"bundle_hit"
	at.tags = [&"損害"]
	var actor_x := EQReservation.new(&"x", at)
	var actor_y := EQReservation.new(&"y", at)
	actor_x.target_id = &"y"
	actor_y.target_id = &"x"
	var reaction_def := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction_def.duration = EQActionDefinition.DURATION_UNLIMITED
	var reaction_cond := EQCondition.new()
	reaction_cond.match_source = &"x"
	reaction_cond.require_tags = [&"損害"]
	rr.submit(EQReservation.new(&"y", reaction_def), reaction_cond)
	rr.set_order_hook(func(candidates: Array) -> Array:
		return [1, 0] if candidates.size() >= 2 else candidates
	)
	var bundle_id := rr.submit_bundle([actor_x, actor_y], 0)
	t.eq(bundle_id != &"", true, "submit_bundle creates a bundle id")
	var got := rr.resolve_next()
	t.eq(got != null, true, "bundle path returns a resolved reservation")
	t.eq(seen.size(), 2, "both bundle members add effects before a single sweep")
	t.eq(rr.runtime.scheduler.size(), 1, "bundle-level sweep schedules one armed reaction")
	var lines := rr.runtime.trace_jsonl().split("\n")
	var idx_bundle := _line_index(lines, "\"kind\":\"bundle_resolved\"")
	var idx_reaction := _line_index(lines, "\"kind\":\"reaction_fired\"")
	t.ok(idx_bundle >= 0, "bundle_resolved trace is present")
	t.ok(idx_reaction >= 0, "reaction_fired trace is present")
	t.ok(idx_bundle < idx_reaction, "reaction_fired appears only after bundle_resolved")
	var next := rr.resolve_next()
	t.eq(next != null and next.actor_id == &"y", true, "bundle sweep reaction resolves on the next pop")


static func _test_bundle_member_lazy_invalidation(t) -> void:
	var rr := _rr([&"hero"])
	rr.lines.issue(&"hp.hero", 0, 1)
	var seen: Array[StringName] = []
	rr.runtime.register_effect(&"drain_hp", func(_v: Dictionary) -> Array:
		rr.lines.advance(&"hp.hero", -1)
		return [_record(&"drain_hp")]
	)
	rr.runtime.register_effect(&"nope", func(_v: Dictionary) -> Array:
		seen.append(&"unexpected")
		return []
	)
	var lead := _def(EQActionDefinition.Kind.IMMEDIATE)
	lead.effect_name = &"drain_hp"
	var a := EQReservation.new(&"hero", lead)
	var fall := _def(EQActionDefinition.Kind.IMMEDIATE)
	fall.effect_name = &"nope"
	var spec := _line_spec(&"hp.hero", 0)
	spec.condition_id = &"owner_hp_depleted"
	fall.invalidation_conditions = [spec]
	var b := EQReservation.new(&"hero", fall)
	var bundle_id := rr.submit_bundle([a, b], 0)
	t.eq(bundle_id != &"", true, "bundle including a pending invalidation member is accepted at submit")
	rr.resolve_next()
	t.eq(a.status, EQReservation.Status.RESOLVED, "lead member resolved")
	t.eq(b.status, EQReservation.Status.INVALIDATED, "lazy invalidation member is invalidated during bundle processing")
	t.eq(seen.size(), 0, "invalidated member produces no effect")
	t.ok('"closed_by":"owner_hp_depleted"' in rr.runtime.trace_jsonl(), "invalidated member is traced with closed_by")


static func _test_bundle_reject_invalid_inputs(t) -> void:
	var rr := _rr([&"hero"])
	t.eq(rr.submit_bundle([]), &"", "empty bundle rejects")
	t.eq(rr.submit_bundle([null]), &"", "null bundle member rejects")
	t.eq(rr.submit_bundle([EQReservation.new(&"hero", _def(EQActionDefinition.Kind.IMMEDIATE)), null]), &"", "array with null after one valid member rejects with rollback")
	var wait := _def(EQActionDefinition.Kind.WAIT)
	t.eq(rr.submit_bundle([EQReservation.new(&"hero", wait)]), &"", "WAIT member is rejected")
	var ready := _def(EQActionDefinition.Kind.READY)
	t.eq(rr.submit_bundle([EQReservation.new(&"hero", ready)]), &"", "READY member is rejected")
	var op := _def(EQActionDefinition.Kind.OPERATION)
	op.operation_target_tag = &"counter"
	t.eq(rr.submit_bundle([EQReservation.new(&"hero", op)]), &"", "OPERATION member is rejected")
	t.eq(rr.runtime.scheduler.is_empty(), true, "rejected bundles never leave scheduled members")


static func _test_non_bundle_resolve_path_unchanged(t) -> void:
	var rr := _rr([&"hero"])
	rr.runtime.register_effect(&"normal", func(_v: Dictionary) -> Array:
		return [_record(&"normal")]
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"normal"
	rr.submit(EQReservation.new(&"hero", d))
	var got := rr.resolve_next()
	t.eq(got.actor_id, &"hero", "normal resolve path still resolves")
	t.eq(rr.last_drained.size(), 1, "non-bundle path drains exactly once")
	t.eq(rr.runtime.trace_jsonl().find("\"kind\":\"bundle_resolved\""), -1, "non-bundle resolve does not emit bundle traces")


static func _golden(t) -> void:
	var jsonl := _build_fairness_bundle_trace()
	var update := OS.get_environment("EQ_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		_write_golden(t, jsonl)
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via EQ_UPDATE_GOLDEN=fairness_bundle)" % GOLDEN_PATH)
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		_dump_actual(jsonl)
	t.eq(jsonl, want, "fairness bundle trace matches fixture")


static func _build_fairness_bundle_trace() -> String:
	var rr := _rr([&"x", &"y"])
	rr.runtime.register_effect(&"damage", func(view: Dictionary) -> Array:
		var rec := _record(&"damage")
		rec.source = StringName(view["source"])
		rec.target = StringName(view["target"])
		return [rec]
	)
	var reaction_def := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction_def.duration = EQActionDefinition.DURATION_UNLIMITED
	reaction_def.priority = 5
	var reaction_cond := EQCondition.new()
	reaction_cond.match_source = &"x"
	reaction_cond.require_tags = [&"損害"]
	rr.submit(EQReservation.new(&"y", reaction_def), reaction_cond)
	var atk_def := _def(EQActionDefinition.Kind.IMMEDIATE)
	atk_def.effect_name = &"damage"
	atk_def.tags = [&"損害"]
	var x_action := EQReservation.new(&"x", atk_def)
	var y_action := EQReservation.new(&"y", atk_def)
	x_action.target_id = &"y"
	y_action.target_id = &"x"
	rr.set_order_hook(func(candidates: Array) -> Array:
		return [1, 0] if candidates.size() >= 2 else candidates
	)
	rr.submit_bundle([x_action, y_action], 0)
	rr.resolve_next()
	rr.resolve_next()
	return rr.runtime.trace_jsonl()


static func _write_golden(t, jsonl: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	if f == null:
		t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
		return
	f.store_string(jsonl)
	f.close()
	t.ok(true, "golden re-baselined for %s via EQ_UPDATE_GOLDEN=%s" % [GOLDEN_CASE, GOLDEN_CASE])


static func _dump_actual(jsonl: String) -> void:
	var out := OS.get_environment("EQ_RUN_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out + "/traces")
	var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
	if f != null:
		f.store_string(jsonl)
		f.close()
