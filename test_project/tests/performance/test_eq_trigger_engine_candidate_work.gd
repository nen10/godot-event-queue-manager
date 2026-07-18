extends RefCounted
## EQM-136 performance lane: deterministic production-engine work gate plus an
## advisory wall-clock observation. This file is never run by the regression lane.

const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")

const TOTAL_ARMS := 1000
const TARGET_COUNT := 40
const WILDCARD_EVERY := 20
const RESOLVING_TARGET := &"target-7"


class CountingCondition extends EQCondition:
	var match_calls: int = 0

	func matches(view: Dictionary) -> bool:
		match_calls += 1
		return super.matches(view)


static func run(t) -> void:
	var engine := EQTriggerEngine.new()
	var conditions: Array[CountingCondition] = []
	var expected_candidates := 0

	for i in range(TOTAL_ARMS):
		var definition := EQActionDefinition.new()
		definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
		definition.duration = EQActionDefinition.DURATION_UNLIMITED
		var reservation := EQReservation.new(StringName("actor-%d" % i), definition)
		var condition := CountingCondition.new()
		if i % WILDCARD_EVERY == 0:
			condition.match_target = &""
			expected_candidates += 1
		else:
			condition.match_target = StringName("target-%d" % (i % TARGET_COUNT))
			if condition.match_target == RESOLVING_TARGET:
				expected_candidates += 1
		# Keep every candidate armed after the sweep while still executing the
		# complete condition matcher.
		condition.require_tags = [&"never-present"]
		conditions.append(condition)
		engine.arm(reservation, condition, 0)

	var started_usec := Time.get_ticks_usec()
	var fired := engine.on_event_resolved_occurrences(
		{"kind": &"hit", "source": &"enemy", "target": RESOLVING_TARGET, "tags": []},
		1
	)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var actual_match_calls := 0
	for condition in conditions:
		actual_match_calls += condition.match_calls

	t.eq(fired.size(), 0, "non-matching performance workload keeps every arm open")
	t.eq(engine.armed_count(), TOTAL_ARMS, "performance sweep preserves all non-matching arms")
	t.eq(
		actual_match_calls,
		expected_candidates,
		"production engine evaluates only target-bucket plus wildcard candidates"
	)
	t.ok(expected_candidates < TOTAL_ARMS / 4, "candidate work is structurally below a full armed scan")
	print(
		"[performance] trigger-candidate-work total_arms=%d candidates=%d match_calls=%d elapsed_usec=%d"
		% [TOTAL_ARMS, expected_candidates, actual_match_calls, elapsed_usec]
	)
