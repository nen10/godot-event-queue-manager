extends RefCounted
## EQM-050: reservation schema validation per kind + .tres roundtrip.

const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_valid_kinds(t)
	_test_kind_constraints(t)
	_test_numeric_fields(t)
	_test_roundtrip(t)


static func _def(kind: int) -> EQActionDefinition:
	var d := EQActionDefinition.new()
	d.kind = kind
	return d


static func _test_valid_kinds(t) -> void:
	var immediate := _def(EQActionDefinition.Kind.IMMEDIATE)  # delay 0 default
	t.ok(immediate.validate().is_valid(), "IMMEDIATE with delay 0 is valid")

	var prepared := _def(EQActionDefinition.Kind.PREPARED)
	prepared.delay = 3
	t.ok(prepared.validate().is_valid(), "PREPARED with delay > 0 is valid")

	var reaction := _def(EQActionDefinition.Kind.REACTION_PREPARATION)
	reaction.duration = EQActionDefinition.DURATION_UNLIMITED  # ∞ — closes by reaction count (Q06)
	t.ok(reaction.validate().is_valid(), "REACTION_PREPARATION with unlimited duration is valid")

	var wait := _def(EQActionDefinition.Kind.WAIT)
	t.ok(wait.validate().is_valid(), "WAIT is valid")
	var ready := _def(EQActionDefinition.Kind.READY)
	t.ok(ready.validate().is_valid(), "READY is valid")

	var op := _def(EQActionDefinition.Kind.OPERATION)
	op.operation_target_tag = &"counter"
	t.ok(op.validate().is_valid(), "OPERATION with a target tag is valid")


static func _test_kind_constraints(t) -> void:
	var bad_immediate := _def(EQActionDefinition.Kind.IMMEDIATE)
	bad_immediate.delay = 5
	t.ok(bad_immediate.validate().has_code(EQError.RESERVATION_IMMEDIATE_NONZERO_DELAY), "IMMEDIATE + delay>0 -> immediate_nonzero_delay")

	var bad_prepared := _def(EQActionDefinition.Kind.PREPARED)  # delay 0
	t.ok(bad_prepared.validate().has_code(EQError.RESERVATION_PREPARED_ZERO_DELAY), "PREPARED + delay 0 -> prepared_zero_delay")

	var bad_reaction := _def(EQActionDefinition.Kind.REACTION_PREPARATION)  # duration 0
	t.ok(bad_reaction.validate().has_code(EQError.RESERVATION_REACTION_NEEDS_DURATION), "REACTION_PREPARATION + duration 0 -> reaction_needs_duration")

	var bad_op := _def(EQActionDefinition.Kind.OPERATION)  # empty target tag
	t.ok(bad_op.validate().has_code(EQError.RESERVATION_OPERATION_NEEDS_TARGET), "OPERATION + empty tag -> operation_needs_target")


static func _test_numeric_fields(t) -> void:
	var neg_delay := _def(EQActionDefinition.Kind.PREPARED)
	neg_delay.delay = -1
	t.ok(neg_delay.validate().has_code(EQError.RESERVATION_NEGATIVE_DELAY), "negative delay -> negative_delay")

	var neg_rum := _def(EQActionDefinition.Kind.IMMEDIATE)
	neg_rum.rumination = -2
	t.ok(neg_rum.validate().has_code(EQError.RESERVATION_NEGATIVE_RUMINATION), "negative rumination -> negative_rumination")

	var bad_dur := _def(EQActionDefinition.Kind.IMMEDIATE)
	bad_dur.duration = -2  # < -1
	t.ok(bad_dur.validate().has_code(EQError.RESERVATION_INVALID_DURATION), "duration < -1 -> invalid_duration")
	var ok_inf := _def(EQActionDefinition.Kind.IMMEDIATE)
	ok_inf.duration = EQActionDefinition.DURATION_UNLIMITED
	t.ok(ok_inf.validate().is_valid(), "duration -1 (unlimited) is valid")


static func _test_roundtrip(t) -> void:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.PREPARED
	d.delay = 7
	d.tags = [&"attack", &"fire"]
	d.duration = 4
	d.rumination = 2
	d.operation_target_tag = &"x"
	var path := "user://eqm_test_action_def.tres"
	t.eq(ResourceSaver.save(d, path), OK, "EQActionDefinition saves to .tres")
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	t.eq(loaded.kind, EQActionDefinition.Kind.PREPARED, "kind survives roundtrip")
	t.eq(loaded.delay, 7, "delay survives roundtrip")
	t.eq(loaded.tags, [&"attack", &"fire"] as Array[StringName], "tags survive roundtrip")
	t.eq(loaded.duration, 4, "duration survives roundtrip")
	t.eq(loaded.rumination, 2, "rumination survives roundtrip")
