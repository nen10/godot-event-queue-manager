extends RefCounted
## EQM-121: STATE algebra + wrapper stack + determinism/lifetime compositions (SEM §5.7 / §6.3).

const EQStateAlgebra := preload("res://addons/event_queue_manager/runtime/eq_state_algebra.gd")
const EQEventLines := preload("res://addons/event_queue_manager/runtime/eq_event_lines.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")
const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")

const GOLDEN_CASE := "lifetime_composition"
const GOLDEN_PATH := "res://tests/golden/lifetime_composition.trace.jsonl"


static func run(t) -> void:
	_test_cancel_arithmetic(t)
	_test_exclude_clear_before_grant_trace(t)
	_test_coexist_independent(t)
	_test_wrap_unwrap_lifo_and_trace(t)
	_test_roundtrip_dict_and_axes(t)
	_test_redeclare_pair_replacement(t)
	_test_faults(t)
	_test_lifetime_composition_golden(t)


static func _test_cancel_arithmetic(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	t.ok(s.declare_inv_pair(&"depletion", &"embellish", EQStateAlgebra.Rule.CANCEL), "declare cancellation pair")
	s.grant_state(&"hero", &"depletion", 3)
	t.eq(s.stacks_of(&"hero", &"depletion"), 3, "initial grants apply to declaration order")
	t.eq(s.stacks_of(&"hero", &"embellish"), 0, "reverse side starts empty")
	t.eq(s.active_state(&"hero", &"depletion"), &"depletion", "positive axis activates state_a")

	s.grant_state(&"hero", &"embellish", 1)
	t.eq(lines.value_of(&"eqm.axis.hero.depletion__embellish"), 2, "CANCEL arithmetic keeps one axis")
	t.eq(s.stacks_of(&"hero", &"depletion"), 2, "CANCEL stacks clamp to 0 for the non-sign")
	t.eq(s.stacks_of(&"hero", &"embellish"), 0, "reverse side is 0 when axis is positive")
	t.eq(s.active_state(&"hero", &"embellish"), &"depletion", "active side reports state_a when axis is positive")

	s.grant_state(&"hero", &"embellish", 5)
	t.eq(lines.value_of(&"eqm.axis.hero.depletion__embellish"), -3, "reverse grants subtract from axis")
	t.eq(s.active_state(&"hero", &"embellish"), &"embellish", "negative axis activates state_b")
	t.eq(s.stacks_of(&"hero", &"depletion"), 0, "reverse side gives 0 for stacks_of")
	t.eq(s.stacks_of(&"hero", &"embellish"), 3, "reverse stacks_of exposes active direction amount")


static func _test_exclude_clear_before_grant_trace(t) -> void:
	var tr := EQTrace.new()
	var lines := EQEventLines.new(tr)
	var s := EQStateAlgebra.new(lines, tr)
	t.ok(s.declare_inv_pair(&"stun", &"fear", EQStateAlgebra.Rule.EXCLUDE), "declare exclusion pair")
	s.grant_state(&"hero", &"stun", 2)
	s.grant_state(&"hero", &"fear", 1)

	var rows := _json_rows(tr.to_jsonl())
	var clear_idx := -1
	var fear_idx := -1
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		if String(row.get("kind", "")) != "event_line_progressed":
			continue
		if String(row.get("line", "")) == "eqm.state.hero.stun" and int(row.get("from", 0)) == 2 and int(row.get("to", 0)) == 0:
			clear_idx = i
		if String(row.get("line", "")) == "eqm.state.hero.fear" and int(row.get("to", 0)) == 1:
			fear_idx = i
	t.eq(clear_idx >= 0, true, "EXCLUDE clear writes a zeroing line_progressed trace")
	t.eq(fear_idx >= 0, true, "EXCLUDE grant writes the grant line_progressed trace")
	t.ok(clear_idx < fear_idx, "clear to dual zero happens before grant")
	t.eq(s.stacks_of(&"hero", &"stun"), 0, "dual is zero after clear")
	t.eq(s.stacks_of(&"hero", &"fear"), 1, "target is granted after clear")


static func _test_coexist_independent(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	s.grant_state(&"hero", &"hasted", 2)
	s.grant_state(&"hero", &"guarded", 5)
	t.eq(s.stacks_of(&"hero", &"hasted"), 2, "undeclared pair behaves as independent state line")
	t.eq(s.stacks_of(&"hero", &"guarded"), 5, "another undeclared state is independent")
	t.eq(s.active_state(&"hero", &"hasted"), &"hasted", "positive independent stack is active")
	t.eq(s.active_state(&"hero", &"guarded"), &"guarded", "independent states can be simultaneously active")
	t.eq(s.active_state(&"hero", &"never_granted"), &"", "zero-stack independent state is inactive (regression: broken ternary returned bool)")
	s.clear_state(&"hero", &"hasted")
	t.eq(s.active_state(&"hero", &"hasted"), &"", "cleared independent state is inactive")


static func _test_wrap_unwrap_lifo_and_trace(t) -> void:
	var tr := EQTrace.new()
	var lines := EQEventLines.new(tr)
	var s := EQStateAlgebra.new(lines, tr)
	s.wrap_state(&"hero", &"focus", {"name": &"shield", "params": {"power": 1}})
	s.wrap_state(&"hero", &"focus", {"name": &"curse", "params": {"power": 2}})
	t.eq(s.wrappers_of(&"hero", &"focus").size(), 2, "wrappers preserve wrap order")

	var rows := _json_rows(tr.to_jsonl())
	var wrap_indices := _trace_indices(rows, "state_wrapped", "depth")
	t.eq(wrap_indices.size(), 2, "two state_wrapped records")
	t.eq(wrap_indices[0] < wrap_indices[1], true, "wrapping is recorded in push order")

	var u1 := s.unwrap_state(&"hero", &"focus")
	t.eq(StringName(u1.get("name", "")), &"curse", "LIFO unwrap returns the top wrapper first")
	var u2 := s.unwrap_state(&"hero", &"focus")
	t.eq(StringName(u2.get("name", "")), &"shield", "second unwrap returns the previous wrapper")
	t.eq(s.wrappers_of(&"hero", &"focus").is_empty(), true, "stack empty after two unwraps")

	rows = _json_rows(tr.to_jsonl())
	t.ok(_depth_row(rows, "state_wrapped", &"curse") == 2, "state_wrapped depth is recorded")
	t.ok(_depth_row(rows, "state_unwrapped", &"curse") == 2, "state_unwrapped depth is recorded")
	t.ok(_depth_row(rows, "state_unwrapped", &"shield") == 1, "LIFO stack unwind decrements depth")


static func _test_roundtrip_dict_and_axes(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	t.ok(s.declare_inv_pair(&"depletion", &"embellish", EQStateAlgebra.Rule.CANCEL), "declare pair for roundtrip")
	s.grant_state(&"hero", &"depletion", 4)
	s.wrap_state(&"hero", &"focus", {"name": &"shield", "params": {"int": 3, "ok": true}})

	var d := s.to_dict()
	var rebuilt_lines := EQEventLines.from_dict(lines.to_dict())
	var restored := EQStateAlgebra.from_dict(d, rebuilt_lines)
	t.eq(restored.stacks_of(&"hero", &"depletion"), 4, "axis stack survives roundtrip")
	t.eq(restored.active_state(&"hero", &"depletion"), &"depletion", "active state survives roundtrip")
	t.eq(restored.wrappers_of(&"hero", &"focus").size(), 1, "wrappers survive roundtrip")
	t.eq(StringName(restored.wrappers_of(&"hero", &"focus")[0].get("name", "")), &"shield", "wrapper name survives roundtrip")
	t.eq(restored.to_dict(), d, "to_dict/from_dict roundtrip is deterministic")

	var axis := StringName("eqm.axis.hero.depletion__embellish")
	t.eq(rebuilt_lines.value_of(axis), 4, "axis value is restored via EQEventLines (line data is externalized)")


static func _test_redeclare_pair_replacement(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	t.ok(s.declare_inv_pair(&"state_a", &"state_b", EQStateAlgebra.Rule.CANCEL), "declare initial pair")
	s.grant_state(&"hero", &"state_a", 2)
	t.eq(s.active_state(&"hero", &"state_a"), &"state_a", "initial declaration is used")

	t.ok(s.declare_inv_pair(&"state_a", &"state_b", EQStateAlgebra.Rule.COEXIST), "re-declare pair with replacement rule")
	s.clear_state(&"hero", &"state_a")
	s.grant_state(&"hero", &"state_a", 2)
	t.eq(s.active_state(&"hero", &"state_a"), &"state_a", "re-declared COEXIST is active independently")
	t.eq(s.stacks_of(&"hero", &"state_b"), 0, "COEXIST replacement severs CANCEL directionality")

	var d := s.to_dict()
	var pair := d.get("inv_pairs", [])[0] as Dictionary
	t.eq(int(pair.get("rule", -1)), EQStateAlgebra.Rule.COEXIST, "pair rule replacement is serialized")


static func _test_faults(t) -> void:
	var lines := EQEventLines.new()
	var s := EQStateAlgebra.new(lines)
	t.eq(s.declare_inv_pair(&"", &"depletion", EQStateAlgebra.Rule.CANCEL), false, "empty state name faults")
	t.eq(s.faults.size(), 1, "empty name emits one fault")

	var empty := s.unwrap_state(&"hero", &"focus")
	t.eq(empty.is_empty(), true, "unwrap of empty wrapper stack returns {}")
	t.eq(s.faults.size(), 2, "unwrap empty emits one more fault")
	t.eq(s.wrappers_of(&"", &"" ).is_empty(), true, "invalid query returns no wrappers")


static func _test_lifetime_composition_golden(t) -> void:
	var jsonl := _build_lifetime_composition_trace()
	t.ok('"closed_by":"reaction_count"' in jsonl, "decrement-counter lifetime closes by closed_by: reaction_count")
	t.ok('"closed_by":"duration"' in jsonl, "duration-5 lifetime closes by closed_by: duration")
	t.ok('"closed_by":"manual_invalidate"' in jsonl, "no-turn condition lifetime closes only by explicit invalidation")
	t.ok('"line":"eqm.axis.hero.depletion__embellish"' in jsonl and '"to":2' in jsonl, "CANCEL grant arithmetic reaches axis 2 and is traced")

	var update := OS.get_environment("EQ_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
		var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		if f == null:
			t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
			return
		f.store_string(jsonl)
		f.close()
		t.ok(true, "golden re-baselined for %s via EQ_UPDATE_GOLDEN=%s" % [GOLDEN_CASE, GOLDEN_CASE])
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s" % GOLDEN_PATH)
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		var out := OS.get_environment("EQ_RUN_OUT")
		if out != "":
			DirAccess.make_dir_recursive_absolute(out + "/traces")
			var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
			if f != null:
				f.store_string(jsonl)
				f.close()
		t.eq(jsonl, want, "state algebra + lifetime composition trace matches golden")


static func _build_lifetime_composition_trace() -> String:
	var tr := EQTrace.new()
	var rr := _runtime_with_trace(tr)
	var lines := rr.lines
	var algebra := EQStateAlgebra.new(lines, tr)

	# 1) 3-count closure by reaction/rumination semantics.
	algebra.declare_inv_pair(&"depletion", &"embellish", EQStateAlgebra.Rule.CANCEL)
	rr.submit(_reaction(&"hero", 2, EQActionDefinition.DURATION_UNLIMITED), _counter_condition(&"hero"))
	for _i in 3:
		rr.submit(_damage(&"orc", &"hero"))
		rr.resolve_next()
		rr.resolve_next()
	# 3 consumes the armed slot -> closed_by: reaction_count.

	# 2) duration 5 expiry closure.
	rr.submit(_reaction(&"orc", 0, 5))
	rr.resolve_next()

	# 3) no turn declaration means tick does not close, explicit invalidation does.
	rr.submit(_reaction(&"mage", 0, EQActionDefinition.DURATION_UNLIMITED))
	for _i in 6:
		rr.step_tick()
	rr.invalidate_actor(&"mage", &"manual_invalidate")

	# 4) cancellation trace: grant with reverse grant to prove axis arithmetic.
	algebra.grant_state(&"hero", &"depletion", 3)
	algebra.grant_state(&"hero", &"embellish", 1)
	return tr.to_jsonl()


static func _runtime_with_trace(tr: EQTrace) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime._trace = tr
	rr.lines = EQEventLines.new(tr)
	for a in [&"hero", &"orc", &"mage"]:
		rr.runtime.register_actor(a)
	return rr


static func _reaction(owner: StringName, rumination: int, duration: int) -> EQReservation:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	d.rumination = rumination
	d.duration = duration
	return EQReservation.new(owner, d)


static func _counter_condition(owner: StringName) -> EQCondition:
	var c := EQCondition.new()
	c.match_target = owner
	c.require_tags = [&"damage"]
	return c


static func _damage(source: StringName, target: StringName) -> EQReservation:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.IMMEDIATE
	d.tags = [&"damage"]
	var r := EQReservation.new(source, d)
	r.target_id = target
	return r


static func _json_rows(trace_jsonl: String) -> Array:
	var rows: Array = []
	for line in trace_jsonl.split("\n"):
		if line == "":
			continue
		var v: Variant = JSON.parse_string(line)
		if v is Dictionary:
			rows.append(v)
	return rows


static func _trace_indices(rows: Array, kind: String, _unused_key: String = "") -> Array:
	var out: Array = []
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		if String(row.get("kind", "")) == kind:
			out.append(i)
	return out


static func _depth_row(rows: Array, kind: String, wrapper_name: StringName) -> int:
	for row in rows:
		if String(row.get("kind", "")) == kind and String(row.get("wrapper", "")) == String(wrapper_name):
			return int(row.get("depth", -1))
	return -1
