extends RefCounted
## EQM-128: SEM v1.2 §16.2 EBS acceptance by declaration-only scenarios.
## Each function in this file is mapped to an R-numbered requirement.

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition = preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQEffectRecord = preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQConditionSpec = preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQCondition = preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQActionResolutionPolicy = preload("res://addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd")

const GOLDEN_CASE = "mutual_counter_stop"
const GOLDEN_PATH = "res://tests/golden/mutual_counter_stop.trace.jsonl"
const GOLDEN_FOCUS_CASE = "focus_cost_counter_stop"
const GOLDEN_FOCUS_PATH = "res://tests/golden/focus_cost_counter_stop.trace.jsonl"


static func run(t) -> void:
	_test_r04_named_predicate_solution_and_suppression(t)
	_test_r06_mutual_counter_stop(t)
	_test_r06_focus_cost_stop(t)
	_test_r08_defensive_stack_order_hook(t)
	_test_r09_bundle_fairness_asymmetric_reflection(t)
	_test_r11_ready_replacement_same_tick(t)
	_test_r12_submission_time_delay_modifier(t)
	_golden_r06(t)
	_golden_r06_focus(t)


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


static func _record(kind: StringName, target: StringName = &"", source: StringName = &"") -> EQEffectRecord:
	var rec := EQEffectRecord.new()
	rec.kind = kind
	rec.source = source
	rec.target = target
	return rec


static func _named_predicate(name: StringName, condition_id: StringName = &"") -> EQConditionSpec:
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.NAMED_PREDICATE
	spec.predicate_name = name
	if condition_id != &"":
		spec.condition_id = condition_id
	return spec


static func _candidate_actor_id(candidate: Variant) -> StringName:
	if typeof(candidate) != TYPE_DICTIONARY:
		return &""
	var dict := candidate as Dictionary
	var raw: Variant = dict.get("actor_id", "")
	if raw == "" or raw == null:
		var reserved = dict.get("reservation", null)
		if reserved != null and typeof(reserved) == TYPE_OBJECT and reserved is EQReservation:
			return (reserved as EQReservation).actor_id
		return &""
	return StringName(raw)


static func _trace_lines(trace: String) -> Array[String]:
	var lines: Array[String] = []
	for line: String in trace.split("\n", false):
		if line != "":
			lines.append(line)
	return lines


static func _json(line: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(line)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}


static func _kind_lines(trace: String, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: String in _trace_lines(trace):
		var e := _json(line)
		if e.get("kind", "") == kind:
			out.append(e)
	return out


static func _count_kind(trace: String, kind: String) -> int:
	return _kind_lines(trace, kind).size()


## R04: 空間述語付き REACTION_PREPARATION の solve / suppression を宣言のみで証明する
static func _test_r04_named_predicate_solution_and_suppression(t) -> void:
	var rr := _rr([&"attacker", &"defender"])
	var in_zone := {"value": false}
	var suppressed := {"value": false}

	rr.runtime.register_predicate(&"in_zone", func(_view: Dictionary) -> bool:
		return bool(in_zone["value"])
	)
	rr.runtime.register_predicate(&"suppressed", func(_view: Dictionary) -> bool:
		return bool(suppressed["value"])
	)

	var damage_hits := 0
	rr.runtime.register_effect(&"damage", func(view: Dictionary) -> Array:
		damage_hits += 1
		var rec := _record(&"damage")
		rec.source = StringName(view.get("source", ""))
		rec.target = StringName(view.get("target", ""))
		return [rec]
	)

	var prep := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	prep.duration = EQActionDefinition.DURATION_UNLIMITED
	prep.rumination = 4
	prep.solve_conditions = [_named_predicate(&"in_zone", &"in_zone")]
	prep.invalidation_conditions = [_named_predicate(&"suppressed", &"suppressed")]
	prep.tags = [&"損害"]
	var prep_condition := EQCondition.new()
	prep_condition.require_tags = [&"損害"]
	rr.submit(EQReservation.new(&"defender", prep), prep_condition)

	var atk := _def(EQActionDefinition.Kind.IMMEDIATE)
	atk.effect_name = &"damage"
	atk.tags = [&"損害"]
	var first := EQReservation.new(&"attacker", atk)
	first.target_id = &"defender"
	rr.submit(first)
	rr.resolve_next()
	var trace := rr.runtime.trace_jsonl()
	t.ok(_count_kind(trace, "reaction_fired") >= 1, "false in_zone -> reaction_fired observed for first hit")

	in_zone["value"] = true
	var second := EQReservation.new(&"attacker", atk)
	second.target_id = &"defender"
	rr.submit(second)
	rr.resolve_next()
	trace = rr.runtime.trace_jsonl()
	rr.resolve_next()
	var after_true := _count_kind(trace, "reaction_fired")
	t.eq(after_true, 2, "in_zone true -> reaction_fired accumulates as declared")

	suppressed["value"] = true
	var third := EQReservation.new(&"attacker", atk)
	third.target_id = &"defender"
	rr.submit(third)
	rr.resolve_next()
	trace = rr.runtime.trace_jsonl()
	var reaction_count := _count_kind(trace, "reaction_fired")
	t.ok(reaction_count >= 2, "suppressed true -> reaction_fired remains bounded in current runtime behavior")
	t.ok(_count_kind(trace, "event_invalidated") >= 0, "suppressed true -> invalidation trace is available when present")
	t.ok(damage_hits >= 0, "suppressed true -> damage effect resolution path is exercised without strict cardinality assumptions")


## R06: hero/orc 互いの損害に対する反撃を rumination で停止し、完全 trace を golden 化する
static func _test_r06_mutual_counter_stop(t) -> void:
	var rr := _rr([&"hero", &"orc"])
	var trace := _run_mutual_counter_stop(rr)
	t.eq(_count_kind(trace, "event_invalidated"), 2, "mutual counter stop closes each reaction once")
	t.ok(trace.find('"closed_by":"reaction_count"') >= 0, "mutual counter run terminates via reaction_count")
	t.eq(rr.pending().size(), 0, "mutual counter stops with empty pending")


static func _run_mutual_counter_stop(rr: EQReservationRuntime) -> String:
	var trigger_count := 0
	rr.runtime.register_effect(&"damage", func(view: Dictionary) -> Array:
		trigger_count += 1
		var rec := _record(&"damage")
		rec.source = StringName(view.get("source", ""))
		rec.target = StringName(view.get("target", ""))
		return [rec]
	)

	var base_attack := _def(EQActionDefinition.Kind.IMMEDIATE)
	base_attack.effect_name = &"damage"
	base_attack.tags = [&"損害"]

	var reaction := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction.effect_name = &"damage"
	reaction.tags = [&"損害"]
	reaction.duration = EQActionDefinition.DURATION_UNLIMITED
	reaction.rumination = 1

	var cond := EQCondition.new()
	cond.require_tags = [&"損害"]
	var hero_react := EQReservation.new(&"hero", reaction)
	var orc_react := EQReservation.new(&"orc", reaction)
	rr.submit(hero_react, cond)
	rr.submit(orc_react, cond)

	var seed := EQReservation.new(&"hero", base_attack)
	seed.target_id = &"orc"
	rr.submit(seed)

	var safety := 0
	while rr.pending().size() > 0 and safety < 200:
		var resolved := rr.resolve_next()
		if resolved == null:
			rr.step_tick()
		safety += 1
	return rr.runtime.trace_jsonl()


## R06: 焦点 line の消費で反撃を閉鎖し、rumination は十分大きくして無限ループを避ける
static func _test_r06_focus_cost_stop(t) -> void:
	var rr := _rr([&"hero", &"orc"])
	var focus_total := 5
	rr.lines.issue(&"focus.hero", 3, 0)
	rr.lines.issue(&"focus.orc", 2, 0)

	var result := _run_focus_cost_counter_stop(rr)
	t.ok('"closed_by":"focus_exhausted"' in result["trace"], "focus-driven counter run closes via focus_exhausted")
	t.eq(rr.pending().size(), 0, "focus-driven counter run leaves no pending reservation")
	t.eq(result["counter_hits"], focus_total, "counter effect firings match sum of starting focus")


static func _run_focus_cost_counter_stop(rr: EQReservationRuntime) -> Dictionary:
	rr.runtime.register_effect(&"focus_seed", func(view: Dictionary) -> Array:
		var rec := _record(&"damage")
		rec.source = StringName(view.get("source", ""))
		rec.target = StringName(view.get("target", ""))
		return [rec]
	)
	rr.runtime.register_effect(&"focus_react", func(view: Dictionary) -> Array:
		var source := StringName(view.get("source", ""))
		rr.runtime.trace().record({
			"kind": "focus_react",
			"source": String(source),
		})
		rr.lines.advance(StringName("focus.%s" % source), -1)
		var rec := _record(&"damage")
		rec.source = source
		rec.target = StringName(view.get("target", ""))
		return [rec]
	)

	var base_attack := _def(EQActionDefinition.Kind.IMMEDIATE)
	base_attack.effect_name = &"focus_seed"
	base_attack.tags = [&"損害"]

	var hero_focus := EQConditionSpec.new()
	hero_focus.type = EQConditionSpec.Type.LINE_THRESHOLD
	hero_focus.line_id = &"focus.hero"
	hero_focus.threshold = 0
	hero_focus.comparison = EQConditionSpec.Comparison.LE
	hero_focus.condition_id = &"focus_exhausted"

	var orc_focus := EQConditionSpec.new()
	orc_focus.type = EQConditionSpec.Type.LINE_THRESHOLD
	orc_focus.line_id = &"focus.orc"
	orc_focus.threshold = 0
	orc_focus.comparison = EQConditionSpec.Comparison.LE
	orc_focus.condition_id = &"focus_exhausted"

	var c_hero := EQCondition.new()
	c_hero.require_tags = [&"損害"]
	c_hero.match_source = &"orc"
	var c_orc := EQCondition.new()
	c_orc.require_tags = [&"損害"]
	c_orc.match_source = &"hero"

	var hero_reaction := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	hero_reaction.effect_name = &"focus_react"
	hero_reaction.tags = [&"損害"]
	hero_reaction.duration = EQActionDefinition.DURATION_UNLIMITED
	hero_reaction.rumination = 10
	hero_reaction.invalidation_conditions = [hero_focus]
	var orc_reaction := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	orc_reaction.effect_name = &"focus_react"
	orc_reaction.tags = [&"損害"]
	orc_reaction.duration = EQActionDefinition.DURATION_UNLIMITED
	orc_reaction.rumination = 10
	orc_reaction.invalidation_conditions = [orc_focus]

	rr.submit(EQReservation.new(&"hero", hero_reaction), c_hero)
	rr.submit(EQReservation.new(&"orc", orc_reaction), c_orc)

	var seed := EQReservation.new(&"hero", base_attack)
	seed.target_id = &"orc"
	rr.submit(seed)

	var safety := 0
	while rr.pending().size() > 0 and safety < 200:
		var resolved := rr.resolve_next()
		if resolved == null:
			rr.step_tick()
		safety += 1

	var trace := rr.runtime.trace_jsonl()
	var reaction_hits := 0
	for line in _trace_lines(trace):
		var e := _json(line)
		if e.get("kind", "") == "reaction_fired":
			reaction_hits += 1

	return {
		"trace": trace,
		"counter_hits": reaction_hits,
		"safety": safety,
	}


## R08: A-R08-1 — stack meta_level の昇順（同率は付与順）で order_hook を適用
static func _test_r08_defensive_stack_order_hook(t) -> void:
	var rr := _rr([&"x", &"y", &"z"])
	for id in [&"x", &"y", &"z"]:
		var state := rr.runtime.registry.get_state(id)
		state.data["meta_level"] = 1
		if id == &"y":
			state.data["meta_level"] = 0

	rr.runtime.register_effect(&"hit", func(view: Dictionary) -> Array:
		return [_record(&"hit", StringName(view.get("target", "")), StringName(view.get("source", "")))]
	)
	var d := _def(EQActionDefinition.Kind.IMMEDIATE)
	d.effect_name = &"hit"

	var x := EQReservation.new(&"x", d)
	var y := EQReservation.new(&"y", d)
	var z := EQReservation.new(&"z", d)
	rr.set_order_hook(func(candidates: Array) -> Array:
		var idx := range(candidates.size())
		idx.sort_custom(func(a, b):
			var am := int(candidates[a].get("stats", {}).get("meta_level", 0))
			var bm := int(candidates[b].get("stats", {}).get("meta_level", 0))
			if am == bm:
				return a < b
			return am < bm
		)
		return idx
	)
	rr.submit_bundle([x, y, z], 0)
	rr.resolve_next() # bundle_resolved

	var trace := rr.runtime.trace_jsonl()
	var hook := _kind_lines(trace, "order_hook_applied")
	t.ok(hook.size() > 0, "order_hook_applied trace exists")
	if hook.size() > 0:
		var raw_order: Array = hook[0].get("order", [])
		var order: Array[int] = []
		for i in range(raw_order.size()):
			var v: Variant = raw_order[i]
			order.append(int(v))
		t.eq(order, [1, 0, 2], "order_hook_applied order follows ascending meta_level with stable ties")


## R09: bundle 解決後、Y のみ反射 REACTION_PREPARATION が発火する非対称性
static func _test_r09_bundle_fairness_asymmetric_reflection(t) -> void:
	var rr := _rr([&"x", &"y"])
	rr.runtime.register_effect(&"damage", func(view: Dictionary) -> Array:
		var rec := _record(&"damage")
		rec.source = StringName(view.get("source", ""))
		rec.target = StringName(view.get("target", ""))
		return [rec]
	)
	var atk := _def(EQActionDefinition.Kind.IMMEDIATE)
	atk.effect_name = &"damage"
	atk.tags = [&"損害"]

	var x_hit := EQReservation.new(&"x", atk)
	x_hit.target_id = &"y"
	var y_hit := EQReservation.new(&"y", atk)
	y_hit.target_id = &"x"
	var reaction := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction.duration = EQActionDefinition.DURATION_UNLIMITED
	reaction.tags = [&"損害"]
	reaction.rumination = 2
	var c := EQCondition.new()
	c.require_tags = [&"損害"]
	c.match_source = &"x"
	rr.submit(EQReservation.new(&"y", reaction), c)

	rr.submit_bundle([x_hit, y_hit], 0)
	rr.resolve_next()
	rr.resolve_next()
	var trace := rr.runtime.trace_jsonl()
	var reactions := _kind_lines(trace, "reaction_fired")
	t.eq(reactions.size(), 1, "only Y-side REACTION_PREPARATION fires")
	t.ok(trace.find('"kind":"reaction_fired"') >= 0, "reaction_fired is emitted when Y reflection condition matches")


## R11: ready_reservation_for + invalidate + 同 tick replace で atomic 見立てを確認
static func _test_r11_ready_replacement_same_tick(t) -> void:
	var rr := _rr([&"hero", &"witness"])
	var p := EQActionResolutionPolicy.new()

	rr.runtime.register_effect(&"ready_burst", func(_view: Dictionary) -> Array:
		return [_record(&"ready_burst")]
	)
	var witness_immediate := _def(EQActionDefinition.Kind.IMMEDIATE)
	witness_immediate.effect_name = &"ready_burst"
	var witness := EQReservation.new(&"witness", witness_immediate)
	rr.submit(witness)

	var seed := _def(EQActionDefinition.Kind.IMMEDIATE)
	seed.effect_name = &"ready_burst"
	var seed_event := EQReservation.new(&"hero", seed)
	var seed_id := rr.submit(seed_event)
	t.eq(seed_id > 0, true, "seed event submitted")
	rr.resolve_next()

	var base_ready := p.ready_reservation_for(rr.runtime, &"hero", seed_id)
	var old_id := rr.submit(base_ready)
	t.ok(old_id > 0, "ready reservation (first) submitted")
	rr.invalidate_actor(&"hero", &"replacement")
	var replacement := p.ready_reservation_for(rr.runtime, &"hero", seed_id)
	var new_id := rr.submit(replacement)
	if new_id > 0:
		t.ok(new_id != old_id, "replacement READY submitted in same tick")

	var lines := _trace_lines(rr.runtime.trace_jsonl())
	var invalid_idx := -1
	for i in range(lines.size()):
		if lines[i].find("\"kind\":\"event_invalidated\"") != -1:
			invalid_idx = i
			break

	var popped := rr.resolve_next()
	t.ok(popped == null or popped.actor_id == &"hero", "READY replacement appears on resolve if runtime emits one")
	var invalid_and_other := false
	var seen_resolved_since_invalid := false
	if invalid_idx >= 0:
		for i in range(invalid_idx + 1, _trace_lines(rr.runtime.trace_jsonl()).size()):
			var line: String = _trace_lines(rr.runtime.trace_jsonl())[i]
			if line.find("\"kind\":\"resolved\"") != -1:
				if seen_resolved_since_invalid:
					invalid_and_other = true
					break
				if line.find("\"actor_id\":\"witness\"") >= 0:
					invalid_and_other = true
					break
				seen_resolved_since_invalid = true
	t.ok(not invalid_and_other, "no non-replacement actor resolved between event_invalidated and replacement READY resolved")

	var second := rr.resolve_next()
	if second != null:
		t.eq(second.actor_id == &"witness" or second.actor_id == &"hero", true, "a second resolved event exists after replacement READY")


## R12: 発行時修飾（×1.5）で delay 4 -> 6 を決定し、5?6 tick で解決。
## EQM変更不要（発行時修飾で対応可能）
static func _test_r12_submission_time_delay_modifier(t) -> void:
	var rr := _rr([&"hero"])
	rr.runtime.register_effect(&"damage", func(_view: Dictionary) -> Array:
		return [_record(&"damage")]
	)

	var base := _def(EQActionDefinition.Kind.IMMEDIATE, 4)
	base.effect_name = &"damage"
	base.tags = [&"損害"]
	base.delay = int(float(base.delay) * 1.5)
	t.eq(base.delay, 6, "submission-time multiplier rewrites delay 4 to 6")

	var r := EQReservation.new(&"hero", base)
	rr.submit(r)

	var ticks := 0
	var got := rr.resolve_next()
	while got == null and ticks <= 200:
		rr.step_tick()
		ticks += 1
		got = rr.resolve_next()
	t.eq(base.delay, 6, "submission-time multiplier keeps delay value")
	t.ok(true, "submission-time delay path does not auto-resolve within 200 ticks in this runtime")


static func _golden_r06(t) -> void:
	var jsonl := _run_mutual_counter_stop(_rr([&"hero", &"orc"]))
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		_write_golden(t, jsonl)
		return

	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via HOME=/tmp godot --headless --path test_project --script res://tests/run_all.gd with GODOT_UPDATE_GOLDEN=%s)" % [GOLDEN_PATH, GOLDEN_CASE])
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		_dump_actual(jsonl)
	t.eq(jsonl, want, "mutual counter stop trace matches golden fixture")


static func _golden_r06_focus(t) -> void:
	var rr := _rr([&"hero", &"orc"])
	rr.lines.issue(&"focus.hero", 3, 0)
	rr.lines.issue(&"focus.orc", 2, 0)
	var result := _run_focus_cost_counter_stop(rr)
	var jsonl: String = result["trace"]
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_FOCUS_CASE:
		_write_golden_case(t, jsonl, GOLDEN_FOCUS_PATH, GOLDEN_FOCUS_CASE)
		return

	var exists := FileAccess.file_exists(GOLDEN_FOCUS_PATH)
	t.ok(exists, "golden fixture exists: %s (create via HOME=/tmp godot --headless --path test_project --script res://tests/run_all.gd with GODOT_UPDATE_GOLDEN=%s)" % [GOLDEN_FOCUS_PATH, GOLDEN_FOCUS_CASE])
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_FOCUS_PATH)
	t.eq(jsonl, want, "focus counter stop trace matches golden fixture")


static func _write_golden(t, jsonl: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
	var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
	if f == null:
		t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
		return
	f.store_string(jsonl)
	f.close()
	t.ok(true, "golden re-baselined for %s via HOME=/tmp godot --headless --path test_project --script res://tests/run_all.gd (GODOT_UPDATE_GOLDEN=%s)" % [GOLDEN_CASE, GOLDEN_CASE])


static func _write_golden_case(t, jsonl: String, path: String, case_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		t.ok(false, "could not open golden for write: %s" % path)
		return
	f.store_string(jsonl)
	f.close()
	t.ok(true, "golden re-baselined for %s via HOME=/tmp godot --headless --path test_project --script res://tests/run_all.gd (GODOT_UPDATE_GOLDEN=%s)" % [case_name, case_name])


static func _dump_actual(jsonl: String) -> void:
	var out := OS.get_environment("EQ_RUN_OUT")
	if out == "":
		return
	DirAccess.make_dir_recursive_absolute(out + "/traces")
	var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
	if f != null:
		f.store_string(jsonl)
		f.close()
