extends RefCounted
## EQM-111: EQConditionSpec validation, dict/.tres roundtrip, and the
## duration/rumination sugar normalization on EQActionDefinition (SEM §5.6).

const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_validate(t)
	_test_dict_roundtrip(t)
	_test_tres_roundtrip(t)
	_test_nested_validate(t)
	_test_sugar_normalization(t)


static func _line_spec(line: StringName, threshold: int, cmp: int = EQConditionSpec.Comparison.GE) -> EQConditionSpec:
	var s := EQConditionSpec.new()
	s.type = EQConditionSpec.Type.LINE_THRESHOLD
	s.line_id = line
	s.threshold = threshold
	s.comparison = cmp
	return s


static func _test_validate(t) -> void:
	t.ok(_line_spec(&"ct", 100).validate().is_valid(), "LINE_THRESHOLD with line_id is valid")

	var no_line := EQConditionSpec.new()
	no_line.type = EQConditionSpec.Type.LINE_THRESHOLD
	t.ok(no_line.validate().has_code(EQError.CONDITION_LINE_ID_EMPTY), "LINE_THRESHOLD without line_id -> line_id_empty")

	var counter := EQConditionSpec.new()
	counter.type = EQConditionSpec.Type.COUNTER
	counter.counter_start = 3
	t.ok(counter.validate().is_valid(), "COUNTER with start >= 1 is valid")
	counter.counter_start = 0
	t.ok(counter.validate().has_code(EQError.CONDITION_COUNTER_START_INVALID), "COUNTER start 0 -> counter_start_invalid")

	var pred := EQConditionSpec.new()
	pred.type = EQConditionSpec.Type.NAMED_PREDICATE
	t.ok(pred.validate().has_code(EQError.CONDITION_PREDICATE_NAME_EMPTY), "NAMED_PREDICATE without name -> predicate_name_empty")
	pred.predicate_name = &"target_visible"
	t.ok(pred.validate().is_valid(), "NAMED_PREDICATE with name is valid")


static func _test_dict_roundtrip(t) -> void:
	var s := _line_spec(&"wt", 5, EQConditionSpec.Comparison.LE)
	s.relative = true
	s.condition_id = &"duration"
	var back := EQConditionSpec.from_dict(s.to_dict())
	t.eq(back.type, s.type, "type survives dict roundtrip")
	t.eq(back.line_id, s.line_id, "line_id survives dict roundtrip")
	t.eq(back.threshold, s.threshold, "threshold survives dict roundtrip")
	t.eq(back.comparison, s.comparison, "comparison survives dict roundtrip")
	t.eq(back.relative, true, "relative survives dict roundtrip")
	t.eq(back.condition_id, &"duration", "condition_id survives dict roundtrip")


static func _test_tres_roundtrip(t) -> void:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	d.duration = EQActionDefinition.DURATION_UNLIMITED
	var solve := _line_spec(&"ap", 3)
	var inv := EQConditionSpec.new()
	inv.type = EQConditionSpec.Type.COUNTER
	inv.counter_start = 3
	inv.condition_id = &"reaction_count"
	d.solve_conditions = [solve]
	d.invalidation_conditions = [inv]
	var path := "user://eqm_test_condition_spec.tres"
	t.eq(ResourceSaver.save(d, path), OK, "definition with nested condition specs saves to .tres")
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	t.eq(loaded.solve_conditions.size(), 1, "solve conditions survive .tres roundtrip")
	t.eq(loaded.solve_conditions[0].line_id, &"ap", "nested spec line_id survives .tres roundtrip")
	t.eq(loaded.invalidation_conditions[0].counter_start, 3, "nested counter_start survives .tres roundtrip")
	t.eq(loaded.invalidation_conditions[0].condition_id, &"reaction_count", "nested condition_id survives .tres roundtrip")

	# to_dict / from_dict carries the arrays too (EQReservation.to_dict inlines this)
	var back := EQActionDefinition.from_dict(d.to_dict())
	t.eq(back.solve_conditions.size(), 1, "solve conditions survive dict roundtrip")
	t.eq(back.invalidation_conditions[0].type, EQConditionSpec.Type.COUNTER, "invalidation type survives dict roundtrip")
	# backward compat: a v1.0 dict without condition keys loads with empty sets
	var legacy := EQActionDefinition.from_dict({"kind": int(EQActionDefinition.Kind.IMMEDIATE), "delay": 0})
	t.eq(legacy.solve_conditions.size(), 0, "legacy dict (no condition keys) loads with empty solve set")


static func _test_nested_validate(t) -> void:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.IMMEDIATE
	var bad := EQConditionSpec.new()
	bad.type = EQConditionSpec.Type.LINE_THRESHOLD  # missing line_id
	d.solve_conditions = [bad]
	t.ok(d.validate().has_code(EQError.CONDITION_LINE_ID_EMPTY), "definition validate aggregates nested spec issues")

	var solve_counter := EQConditionSpec.new()
	solve_counter.type = EQConditionSpec.Type.COUNTER
	solve_counter.counter_start = 2
	d.solve_conditions = [solve_counter]
	t.ok(
		d.validate().has_code(EQError.CONDITION_COUNTER_SOLVE_UNSUPPORTED),
		"COUNTER is rejected on solve because it cannot self-progress before RESOLVE"
	)


static func _test_sugar_normalization(t) -> void:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	d.duration = 5
	d.rumination = 2
	var declared := _line_spec(&"hp", 0, EQConditionSpec.Comparison.LE)
	d.invalidation_conditions = [declared]
	var n: Dictionary = d.normalized_conditions()
	var inv: Array = n["invalidation"]
	t.eq(inv.size(), 3, "normalization appends duration + reaction_count after declared terms")
	t.eq(inv[0].line_id, &"hp", "declared invalidation term keeps first position")
	t.eq(inv[1].condition_id, &"duration", "duration sugar -> condition_id duration")
	t.eq(inv[1].line_id, EQActionDefinition.PRIMARY_LINE_ID, "duration sugar reads the primary line")
	t.ok(inv[1].relative, "duration sugar is a relative threshold (armed_at + duration)")
	t.eq(inv[1].threshold, 5, "duration sugar threshold = duration")
	t.eq(inv[2].condition_id, &"reaction_count", "rumination sugar -> condition_id reaction_count")
	t.eq(inv[2].type, EQConditionSpec.Type.COUNTER, "rumination sugar is a counter")
	t.eq(inv[2].counter_start, 3, "rumination 2 allows 3 total resolutions")

	# no sugar when duration is unlimited/zero and rumination is 0
	var bare := EQActionDefinition.new()
	bare.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	bare.duration = EQActionDefinition.DURATION_UNLIMITED
	var bn: Dictionary = bare.normalized_conditions()
	t.eq((bn["invalidation"] as Array).size(), 0, "duration -1 (unlimited) adds no sugar term")
	t.eq((bn["solve"] as Array).size(), 0, "no declared solve terms -> empty (vacuous AND)")
