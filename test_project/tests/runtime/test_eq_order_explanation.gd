extends RefCounted
## EQM-091 — explanation-as-data. decided_by is delegated to EQOrdering, so it
## can never disagree with the actual sort; the factors are structured (key/value),
## never prose.

const EQEntry := preload("res://addons/event_queue_manager/runtime/eq_entry.gd")
const EQOrdering := preload("res://addons/event_queue_manager/runtime/eq_ordering.gd")
const EQOrderExplanation := preload("res://addons/event_queue_manager/runtime/eq_order_explanation.gd")


static func run(t) -> void:
	_test_decided_by_each_key(t)
	_test_decided_by_matches_less_than(t)
	_test_factors_structured(t)
	_test_first_entry_has_no_decider(t)
	_test_to_dict_overlay_compatible(t)


static func _e(tick: int, priority: int, sequence: int, actor: StringName) -> EQEntry:
	return EQEntry.make(sequence, tick, priority, sequence, &"turn", actor)


static func _test_decided_by_each_key(t) -> void:
	# tick decides
	var a := _e(3, 0, 1, &"hero")
	var b := _e(5, 0, 2, &"orc")
	t.eq(EQOrderExplanation.of(b, a).decided_by, &"due_tick", "earlier tick decides")
	# same tick -> priority decides (higher first)
	var c := _e(4, 5, 1, &"hero")
	var d := _e(4, 2, 2, &"orc")
	t.eq(EQOrderExplanation.of(d, c).decided_by, &"priority", "same tick -> priority decides")
	# same tick + priority -> sequence decides
	var e := _e(4, 1, 1, &"hero")
	var f := _e(4, 1, 2, &"orc")
	t.eq(EQOrderExplanation.of(f, e).decided_by, &"sequence", "same tick+priority -> sequence decides")


static func _test_decided_by_matches_less_than(t) -> void:
	# whatever decided_by names, less_than must agree the predecessor sorts first
	var a := _e(4, 5, 1, &"hero")
	var b := _e(4, 2, 2, &"orc")
	t.ok(EQOrdering.less_than(a, b), "predecessor sorts before successor")
	t.eq(EQOrdering.decided_by(a, b), EQOrderExplanation.of(b, a).decided_by, "explanation reuses EQOrdering.decided_by")


static func _test_factors_structured(t) -> void:
	var exp := EQOrderExplanation.of(_e(7, 3, 9, &"mage"))
	t.eq(exp.factors.size(), 3, "three ordering factors")
	var keys: Array = []
	for fct in exp.factors:
		keys.append(fct["key"])
		t.ok(fct.has("value") and fct.has("direction"), "factor carries structured value+direction (not prose)")
	t.eq(keys, [&"due_tick", &"priority", &"sequence"], "factors in precedence order")
	t.eq(exp.factors[0]["value"], 7, "due_tick value captured")
	t.eq(exp.factors[1]["value"], 3, "priority value captured")


static func _test_first_entry_has_no_decider(t) -> void:
	var exp := EQOrderExplanation.of(_e(1, 0, 1, &"hero"))
	t.eq(exp.decided_by, &"", "first entry (no predecessor) has empty decided_by")
	t.ok(exp.deciding_factor().is_empty(), "no deciding factor for the first entry")


static func _test_to_dict_overlay_compatible(t) -> void:
	var exp := EQOrderExplanation.of(_e(4, 2, 2, &"orc"), _e(4, 5, 1, &"hero"))
	var d := exp.to_dict()
	t.eq(d["actor"], "orc", "to_dict carries actor (EQDebugOverlay key)")
	t.eq(d["decided_by"], "priority", "to_dict carries decided_by (EQDebugOverlay key)")
	t.ok(d.has("factors"), "to_dict also carries the structured factors")
