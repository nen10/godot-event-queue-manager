extends RefCounted
## EQM-021: action result cost/delay validation.

const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	# valid
	var ok_r := EQActionResult.new(5, 3)
	t.ok(ok_r.validate().is_valid(), "non-negative cost and delay is valid")
	t.eq(ok_r.validate().issues.size(), 0, "valid result has no issues")

	# negative delay is always a contract violation
	var bad_delay := EQActionResult.new(0, -1)
	var vd := bad_delay.validate()
	t.ok(not vd.is_valid(), "negative delay is invalid")
	t.ok(vd.has_code(EQError.ACTION_NEGATIVE_DELAY), "negative delay -> ACTION_NEGATIVE_DELAY")
	t.eq(vd.errors()[0]["recoverability"], EQError.Recoverability.CONTRACT_VIOLATION, "negative delay is a contract violation")

	# negative cost requires the policy to declare it
	var bad_cost := EQActionResult.new(-2, 1)
	t.ok(not bad_cost.validate().is_valid(), "negative cost is invalid by default")
	t.ok(bad_cost.validate().has_code(EQError.ACTION_NEGATIVE_COST), "negative cost -> ACTION_NEGATIVE_COST")
	bad_cost.allow_negative_cost = true
	t.ok(bad_cost.validate().is_valid(), "negative cost is valid when the policy allows it (§12)")
