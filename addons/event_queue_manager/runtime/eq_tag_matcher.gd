class_name EQTagMatcher
extends RefCounted
## Pure tag-set matching helpers used by EQCondition (and the trigger engine).
## An empty constraint is the identity: has_all([], required=[]) and
## has_any(tags, candidates=[]) both mean "no constraint" → true.


static func has_all(tags: Array, required: Array) -> bool:
	for required_tag in required:
		if not tags.has(required_tag):
			return false
	return true


static func has_any(tags: Array, candidates: Array) -> bool:
	if candidates.is_empty():
		return true
	for candidate in candidates:
		if tags.has(candidate):
			return true
	return false
