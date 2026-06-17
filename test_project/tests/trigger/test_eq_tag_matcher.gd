extends RefCounted

const EQTagMatcher := preload("res://addons/event_queue_manager/runtime/eq_tag_matcher.gd")


static func run(t) -> void:
	_test_has_all(t)
	_test_has_any(t)


static func _test_has_all(t) -> void:
	var tags: Array[StringName] = [&"alpha", &"beta", &"gamma"]
	t.ok(EQTagMatcher.has_all(tags, [&"alpha", &"gamma"]), "has_all returns true when all required tags are present")
	t.ok(not EQTagMatcher.has_all(tags, [&"alpha", &"missing"]), "has_all returns false when one required tag is missing")
	t.ok(EQTagMatcher.has_all(tags, []), "has_all returns true for empty required tags")


static func _test_has_any(t) -> void:
	var tags: Array[StringName] = [&"alpha", &"beta", &"gamma"]
	t.ok(EQTagMatcher.has_any(tags, [&"missing", &"beta"]), "has_any returns true when one candidate tag is present")
	t.ok(not EQTagMatcher.has_any(tags, [&"missing", &"other"]), "has_any returns false when no candidate tag is present")
	t.ok(EQTagMatcher.has_any(tags, []), "has_any returns true for empty candidate tags")
