extends RefCounted

const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")


static func run(t) -> void:
	_test_all_criteria_match(t)
	_test_kind_mismatch(t)
	_test_source_mismatch(t)
	_test_target_mismatch(t)
	_test_missing_required_tag(t)
	_test_any_tags_none_present(t)
	_test_wildcard_matches_anything(t)
	_test_required_and_any_tags_combined(t)
	_test_custom_predicate(t)
	_test_sensing_required_placeholder(t)


static func _view(kind: StringName, source: StringName, target: StringName, tags: Array[StringName]) -> Dictionary:
	return {
		"kind": kind,
		"source": source,
		"target": target,
		"tags": tags,
	}


static func _test_all_criteria_match(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.match_kind = &"attack"
	cond.match_source = &"hero"
	cond.match_target = &"slime"
	cond.require_tags = [&"physical", &"melee"]
	cond.any_tags = [&"critical", &"opening"]
	var view: Dictionary = _view(&"attack", &"hero", &"slime", [&"physical", &"melee", &"opening"])
	t.ok(cond.matches(view), "condition matches when all criteria are met")


static func _test_kind_mismatch(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.match_kind = &"attack"
	var view: Dictionary = _view(&"heal", &"hero", &"slime", [])
	t.ok(not cond.matches(view), "condition rejects a kind mismatch")


static func _test_source_mismatch(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.match_source = &"hero"
	var view: Dictionary = _view(&"attack", &"rival", &"slime", [])
	t.ok(not cond.matches(view), "condition rejects a source mismatch")


static func _test_target_mismatch(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.match_target = &"slime"
	var view: Dictionary = _view(&"attack", &"hero", &"bat", [])
	t.ok(not cond.matches(view), "condition rejects a target mismatch")


static func _test_missing_required_tag(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.require_tags = [&"physical", &"melee"]
	var view: Dictionary = _view(&"attack", &"hero", &"slime", [&"physical"])
	t.ok(not cond.matches(view), "condition rejects a missing required tag")


static func _test_any_tags_none_present(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.any_tags = [&"critical", &"opening"]
	var view: Dictionary = _view(&"attack", &"hero", &"slime", [&"physical", &"melee"])
	t.ok(not cond.matches(view), "condition rejects when any_tags are set and none are present")


static func _test_wildcard_matches_anything(t) -> void:
	var cond: EQCondition = EQCondition.new()
	var view: Dictionary = _view(&"heal", &"cleric", &"hero", [&"magic", &"support"])
	t.ok(cond.matches(view), "fully-unset condition matches anything")


static func _test_required_and_any_tags_combined(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.require_tags = [&"physical", &"melee"]
	cond.any_tags = [&"critical", &"opening"]
	var matching_view: Dictionary = _view(&"attack", &"hero", &"slime", [&"physical", &"melee", &"critical"])
	var missing_any_view: Dictionary = _view(&"attack", &"hero", &"slime", [&"physical", &"melee"])
	t.ok(cond.matches(matching_view), "condition accepts combined require_tags and any_tags when both hold")
	t.ok(not cond.matches(missing_any_view), "condition rejects combined tag criteria when any_tags do not hold")


static func _test_custom_predicate(t) -> void:
	var cond: EQCondition = EQCondition.new()
	var view: Dictionary = _view(&"attack", &"hero", &"slime", [])
	cond.custom_predicate = func(v): return v.get("kind", &"") == &"heal"
	t.ok(not cond.matches(view), "custom_predicate returning false blocks a match")
	cond.custom_predicate = func(v): return v.get("kind", &"") == &"attack"
	t.ok(cond.matches(view), "custom_predicate returning true allows a match")


static func _test_sensing_required_placeholder(t) -> void:
	var cond: EQCondition = EQCondition.new()
	cond.sensing_required = true
	var view: Dictionary = _view(&"attack", &"hero", &"slime", [])
	t.ok(cond.matches(view), "sensing_required is a placeholder and does not change matching")
