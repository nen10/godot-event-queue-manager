class_name EQOrderExplanation
extends RefCounted
## Explanation-as-data for why an entry sits at its position (EQM-091).
##
## The runtime emits STRUCTURED data — never a free-form sentence. An explanation
## is the ordering key breakdown (due_tick / priority / sequence) plus `decided_by`:
## the single key that ordered this entry after its predecessor. The UI maps keys
## to icons/short labels; it does not parse prose. `decided_by` is delegated to
## EQOrdering so it can never disagree with the actual sort.

const EQEntry := preload("res://addons/event_queue_manager/runtime/eq_entry.gd")
const EQOrdering := preload("res://addons/event_queue_manager/runtime/eq_ordering.gd")

## Ordering keys in precedence order, with how each is read (higher/lower wins).
const FACTOR_KEYS: Array[StringName] = [&"due_tick", &"priority", &"sequence"]
const FACTOR_DIRECTION := {
	&"due_tick": &"lower_first",   # earlier tick acts first
	&"priority": &"higher_first",  # higher priority first
	&"sequence": &"lower_first",   # earlier scheduled first (the unique tie-break)
}

var actor_id: StringName = &""
var factors: Array = []          # [{key, value, rank, direction}]
var decided_by: StringName = &"" # key that placed this entry after its predecessor (&"" if first)


## Build the explanation for `entry`. If `predecessor` (the entry immediately
## before it in the order) is given, `decided_by` names the key that put `entry`
## after it. With no predecessor the entry is first, so `decided_by` is &"".
static func of(entry: EQEntry, predecessor: EQEntry = null) -> EQOrderExplanation:
	var e := EQOrderExplanation.new()
	e.actor_id = entry.actor_id
	e.factors = [
		_factor(&"due_tick", entry.due_tick, 1),
		_factor(&"priority", entry.priority, 2),
		_factor(&"sequence", entry.sequence, 3),
	]
	e.decided_by = EQOrdering.decided_by(predecessor, entry) if predecessor != null else &""
	return e


static func _factor(key: StringName, value: int, rank: int) -> Dictionary:
	return {"key": key, "value": value, "rank": rank, "direction": FACTOR_DIRECTION[key]}


## The factor dictionary that decided the order (or empty if this entry is first).
func deciding_factor() -> Dictionary:
	for f in factors:
		if f["key"] == decided_by:
			return f
	return {}


## Plain-data form. Compatible with EQDebugOverlay.set_state's explanation dicts
## ({actor, decided_by}); also carries the structured factors.
func to_dict() -> Dictionary:
	return {
		"actor": String(actor_id),
		"decided_by": String(decided_by),
		"factors": factors.duplicate(true),
	}
