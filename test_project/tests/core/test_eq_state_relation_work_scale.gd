extends RefCounted
## EQM-134 / EQM-136 — deterministic correctness at the recorded engineering
## work scale. Wall-clock thresholds are isolated in res://tests/performance/.

const WorkScale := preload("res://tests/support/eq_state_relation_work_scale_fixture.gd")


static func run(t) -> void:
	_test_state_algebra_roundtrip_scale(t)
	_test_relation_roundtrip_scale(t)
	_test_actual_trigger_engine_scale(t)


static func _test_state_algebra_roundtrip_scale(t) -> void:
	var context := WorkScale.setup_state_algebra()
	for pair_index in WorkScale.STATE_PAIRS:
		t.ok(
			context["declarations"][pair_index],
			"state work-scale inverse pair %d is accepted" % pair_index,
		)
	var result := WorkScale.exercise_state_algebra(context)
	var line_snapshot: Dictionary = result["line_snapshot"]
	var algebra_snapshot: Dictionary = result["algebra_snapshot"]

	t.eq(
		line_snapshot["lines"].size(),
		1 + WorkScale.STATE_ACTORS * WorkScale.STATE_PAIRS,
		"cancel pairs store one signed axis per actor and pair plus the primary line",
	)
	t.eq(
		algebra_snapshot["wrappers"].size(),
		WorkScale.STATE_ACTORS * WorkScale.WRAPPERS_PER_ACTOR,
		"work-scale snapshot preserves every declared wrapper stack",
	)
	t.eq(result["rebuilt_line_snapshot"], line_snapshot, "state line work scale round-trips exactly")
	t.eq(
		result["rebuilt_algebra_snapshot"],
		algebra_snapshot,
		"state algebra work scale round-trips exactly",
	)
	t.ok(result["faults"].is_empty(), "state work-scale run records no algebra faults")


static func _test_relation_roundtrip_scale(t) -> void:
	var context := WorkScale.setup_relation_graph()
	t.ok(context["declared"], "work-scale relation type is accepted")
	var result := WorkScale.exercise_relation_graph(context)
	var snapshot: Dictionary = result["snapshot"]

	t.eq(
		snapshot["relations"].size(),
		WorkScale.RELATION_EDGES,
		"work-scale relation edges are all stored",
	)
	t.eq(result["rebuilt_snapshot"], snapshot, "relation work scale round-trips exactly")
	t.ok(result["expanded"].size() >= 2, "bounded expansion remains usable at the recorded edge scale")
	t.ok(result["graph_faults"].is_empty(), "relation work-scale graph records no faults")
	t.ok(result["rebuilt_faults"].is_empty(), "restored relation work-scale graph records no faults")


static func _test_actual_trigger_engine_scale(t) -> void:
	var result := WorkScale.exercise_trigger_engine(WorkScale.setup_trigger_engine())
	t.eq(
		result["fired"].size(),
		WorkScale.ARMED_TRIGGERS,
		"actual trigger engine resolves the recorded armed set",
	)
