extends RefCounted
## EQM-134 / EQM-136 — explicit-lane wall-clock guards at the recorded engineering
## work scale. Exact counts, round-trips, and fault behavior live in regression.

const WorkScale := preload("res://tests/support/eq_state_relation_work_scale_fixture.gd")

# Coarse guards with generous headroom; they catch algorithmic explosions rather
# than defining gameplay limits or stable cross-machine benchmark numbers.
const STATE_ROUNDTRIP_BUDGET_MS := 5000
const RELATION_ROUNDTRIP_BUDGET_MS := 3000
const TRIGGER_SWEEP_BUDGET_MS := 1000


static func run(t) -> void:
	_test_state_algebra_roundtrip_budget(t)
	_test_relation_roundtrip_budget(t)
	_test_actual_trigger_engine_budget(t)


static func _test_state_algebra_roundtrip_budget(t) -> void:
	var context := WorkScale.setup_state_algebra()
	var started_ms := Time.get_ticks_msec()
	var result := WorkScale.exercise_state_algebra(context)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	var line_snapshot: Dictionary = result["line_snapshot"]
	t.eq(
		line_snapshot["lines"].size(),
		1 + WorkScale.STATE_ACTORS * WorkScale.STATE_PAIRS,
		"state budget exercised the complete recorded line set",
	)
	t.ok(
		elapsed_ms <= STATE_ROUNDTRIP_BUDGET_MS,
		"%d actors x %d state tokens round-trip within %dms (took %dms)"
		% [
			WorkScale.STATE_ACTORS,
			WorkScale.STATE_TOKENS_PER_ACTOR,
			STATE_ROUNDTRIP_BUDGET_MS,
			elapsed_ms,
		],
	)


static func _test_relation_roundtrip_budget(t) -> void:
	var context := WorkScale.setup_relation_graph()
	var started_ms := Time.get_ticks_msec()
	var result := WorkScale.exercise_relation_graph(context)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	t.eq(
		result["snapshot"]["relations"].size(),
		WorkScale.RELATION_EDGES,
		"relation budget exercised every recorded edge",
	)
	t.ok(
		elapsed_ms <= RELATION_ROUNDTRIP_BUDGET_MS,
		"%d relation edges round-trip within %dms (took %dms)"
		% [WorkScale.RELATION_EDGES, RELATION_ROUNDTRIP_BUDGET_MS, elapsed_ms],
	)


static func _test_actual_trigger_engine_budget(t) -> void:
	var context := WorkScale.setup_trigger_engine()
	var started_ms := Time.get_ticks_msec()
	var result := WorkScale.exercise_trigger_engine(context)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	t.eq(
		result["fired"].size(),
		WorkScale.ARMED_TRIGGERS,
		"trigger budget exercised every recorded armed reaction",
	)
	t.ok(
		elapsed_ms <= TRIGGER_SWEEP_BUDGET_MS,
		"%d matching armed triggers resolve within %dms (took %dms)"
		% [WorkScale.ARMED_TRIGGERS, TRIGGER_SWEEP_BUDGET_MS, elapsed_ms],
	)
