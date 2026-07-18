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
@export var match_target: StringName = &"":
	set(value):
		if match_target == value:
			return
		match_target = value
		# EQTriggerIndex is derived state. Notify it when an already-armed
		# condition changes buckets so indexed matching stays observationally
		# equivalent to the former linear scan.
		emit_changed()
@export var require_tags: Array[StringName] = []
@export var any_tags: Array[StringName] = []
# Placeholder for the range/sensing adapter (Q12); not evaluated by matches().
@export var sensing_required: bool = false

var custom_predicate: Callable = Callable()


## Serializable form (EQM-117). `custom_predicate` is transient (never
## serialized — SEM §5.5: only NAMES cross a save; direct Callables are for
## conditions that never do).
func to_dict() -> Dictionary:
	return {
		"match_kind": String(match_kind),
		"match_source": String(match_source),
		"match_target": String(match_target),
		"require_tags": require_tags.map(func(x): return String(x)),
		"any_tags": any_tags.map(func(x): return String(x)),
		"sensing_required": sensing_required,
	}


static func from_dict(d: Dictionary) -> EQCondition:
	var c := EQCondition.new()
	c.match_kind = StringName(d.get("match_kind", ""))
	c.match_source = StringName(d.get("match_source", ""))
	c.match_target = StringName(d.get("match_target", ""))
	var req: Array[StringName] = []
	for s in d.get("require_tags", []):
		req.append(StringName(s))
	c.require_tags = req
	var any: Array[StringName] = []
	for s in d.get("any_tags", []):
		any.append(StringName(s))
	c.any_tags = any
	c.sensing_required = bool(d.get("sensing_required", false))
	return c


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
