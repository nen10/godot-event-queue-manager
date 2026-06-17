class_name EQCondition
extends Resource
## Matches a normalized event view ({kind, source, target, tags}) against
## criteria. An unset/empty criterion is a wildcard; all set criteria must hold
## (AND). The trigger engine (EQM-061) builds the view from a resolving event /
## reservation. `custom_predicate` is transient (never serialized, like a weak
## binding); `sensing_required` is a reserved placeholder for the range/sensing
## adapter (Q12), not yet evaluated.

const EQTagMatcher := preload("res://addons/event_queue_manager/runtime/eq_tag_matcher.gd")

@export var match_kind: StringName = &""
@export var match_source: StringName = &""
@export var match_target: StringName = &""
@export var require_tags: Array[StringName] = []
@export var any_tags: Array[StringName] = []
# Placeholder for the range/sensing adapter (Q12); not evaluated by matches().
@export var sensing_required: bool = false

var custom_predicate: Callable = Callable()


func matches(view: Dictionary) -> bool:
	var tags: Array = view.get("tags", [])
	if match_kind != &"" and view.get("kind", &"") != match_kind:
		return false
	if match_source != &"" and view.get("source", &"") != match_source:
		return false
	if match_target != &"" and view.get("target", &"") != match_target:
		return false
	if not EQTagMatcher.has_all(tags, require_tags):
		return false
	if not EQTagMatcher.has_any(tags, any_tags):
		return false
	if custom_predicate.is_valid() and bool(custom_predicate.call(view)) != true:
		return false
	return true
