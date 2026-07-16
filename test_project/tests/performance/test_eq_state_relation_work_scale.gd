extends RefCounted
## EQM-134 — reproducible engineering work scale for state/relation consumers.
##
## These counts are not gameplay limits.  They are a deterministic regression
## ladder rung that exercises the actual state algebra, relation graph, trigger
## engine, and serialization paths together.  Games may choose independent
## content limits; exceeding this recorded rung must not be silently truncated.

const EQActionDefinition := preload(
	"res://addons/event_queue_manager/resources/eq_action_definition.gd"
)
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQEventLines := preload("res://addons/event_queue_manager/runtime/eq_event_lines.gd")
const EQRelationGraph := preload("res://addons/event_queue_manager/runtime/eq_relation_graph.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQStateAlgebra := preload("res://addons/event_queue_manager/runtime/eq_state_algebra.gd")
const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")

const STATE_ACTORS := 8
const STATE_PAIRS := 32
const STATE_TOKENS_PER_ACTOR := STATE_PAIRS * 2
const WRAPPERS_PER_ACTOR := 16
const RELATION_ACTORS := 200
const RELATION_EDGES := 1024
const ARMED_TRIGGERS := 200

# Coarse CI guards.  Correct counts and exact round-trips are the primary gate;
# generous timing headroom only catches accidental algorithmic explosions.
const STATE_ROUNDTRIP_BUDGET_MS := 5000
const RELATION_ROUNDTRIP_BUDGET_MS := 3000
const TRIGGER_SWEEP_BUDGET_MS := 1000


static func run(t) -> void:
	_test_state_algebra_roundtrip_scale(t)
	_test_relation_roundtrip_scale(t)
	_test_actual_trigger_engine_scale(t)


static func _test_state_algebra_roundtrip_scale(t) -> void:
	var lines := EQEventLines.new()
	var algebra := EQStateAlgebra.new(lines)
	for pair_index in STATE_PAIRS:
		t.ok(
			algebra.declare_inv_pair(
				_state_a(pair_index), _state_b(pair_index), EQStateAlgebra.Rule.CANCEL
			),
			"state work-scale inverse pair %d is accepted" % pair_index,
		)
	var started_ms := Time.get_ticks_msec()
	for actor_index in STATE_ACTORS:
		var actor := _actor(actor_index)
		for pair_index in STATE_PAIRS:
			algebra.grant_state(actor, _state_a(pair_index), 1)
			algebra.grant_state(actor, _state_b(pair_index), 2)
		for wrapper_index in WRAPPERS_PER_ACTOR:
			algebra.wrap_state(
				actor,
				_state_a(wrapper_index),
				{
					"name": StringName("wrapper.%03d.%03d" % [actor_index, wrapper_index]),
					"kind": &"inv_chain",
					"params": {},
				},
			)
	var line_snapshot := lines.to_dict()
	var algebra_snapshot := algebra.to_dict()
	var rebuilt_lines := EQEventLines.from_dict(line_snapshot)
	var rebuilt_algebra := EQStateAlgebra.from_dict(algebra_snapshot, rebuilt_lines)
	var elapsed_ms := Time.get_ticks_msec() - started_ms

	t.eq(
		line_snapshot["lines"].size(),
		1 + STATE_ACTORS * STATE_PAIRS,
		"cancel pairs store one signed axis per actor and pair plus the primary line",
	)
	t.eq(
		algebra_snapshot["wrappers"].size(),
		STATE_ACTORS * WRAPPERS_PER_ACTOR,
		"work-scale snapshot preserves every declared wrapper stack",
	)
	t.eq(rebuilt_lines.to_dict(), line_snapshot, "state line work scale round-trips exactly")
	t.eq(rebuilt_algebra.to_dict(), algebra_snapshot, "state algebra work scale round-trips exactly")
	t.ok(algebra.faults.is_empty(), "state work-scale run records no algebra faults")
	t.ok(
		elapsed_ms <= STATE_ROUNDTRIP_BUDGET_MS,
		"%d actors x %d state tokens round-trip within %dms (took %dms)"
		% [STATE_ACTORS, STATE_TOKENS_PER_ACTOR, STATE_ROUNDTRIP_BUDGET_MS, elapsed_ms],
	)


static func _test_relation_roundtrip_scale(t) -> void:
	var graph := EQRelationGraph.new()
	t.ok(
		graph.declare_relation_type(
			{"name": &"work_scale_link", "structure": EQRelationGraph.Structure.GRAPH}
		),
		"work-scale relation type is accepted",
	)
	var started_ms := Time.get_ticks_msec()
	for edge_index in RELATION_EDGES:
		var from_actor := StringName("relation_actor.%03d" % (edge_index % RELATION_ACTORS))
		var to_actor := StringName(
			"relation_actor.%03d" % ((edge_index + 1) % RELATION_ACTORS)
		)
		var relation_id := graph.bind(&"work_scale_link", from_actor, to_actor)
		if relation_id == &"":
			break
	var snapshot := graph.to_dict()
	var rebuilt := EQRelationGraph.new()
	rebuilt.restore(snapshot)
	# One-hop traversal measures the complete relation-table scan without turning
	# this daily rung into the separate cyclic path-expansion stress profile.
	var expanded := rebuilt.expand(&"relation_actor.000", &"work_scale_link", 1, 1)
	var elapsed_ms := Time.get_ticks_msec() - started_ms

	t.eq(snapshot["relations"].size(), RELATION_EDGES, "work-scale relation edges are all stored")
	t.eq(rebuilt.to_dict(), snapshot, "relation work scale round-trips exactly")
	t.ok(expanded.size() >= 2, "bounded expansion remains usable at the recorded edge scale")
	t.ok(graph.faults.is_empty(), "relation work-scale run records no graph faults")
	t.ok(rebuilt.faults.is_empty(), "restored relation work-scale graph records no faults")
	t.ok(
		elapsed_ms <= RELATION_ROUNDTRIP_BUDGET_MS,
		"%d relation edges round-trip within %dms (took %dms)"
		% [RELATION_EDGES, RELATION_ROUNDTRIP_BUDGET_MS, elapsed_ms],
	)


static func _test_actual_trigger_engine_scale(t) -> void:
	var engine := EQTriggerEngine.new()
	for trigger_index in ARMED_TRIGGERS:
		var definition := EQActionDefinition.new()
		definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
		definition.duration = EQActionDefinition.DURATION_UNLIMITED
		definition.rumination = 0
		var condition := EQCondition.new()
		condition.match_target = &"work_scale_target"
		engine.arm(
			EQReservation.new(StringName("trigger_owner.%03d" % trigger_index), definition),
			condition,
			0,
		)
	var started_ms := Time.get_ticks_msec()
	var fired := engine.on_event_resolved(
		{"kind": &"work_scale_event", "target": &"work_scale_target", "tags": []}, 0
	)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	t.eq(fired.size(), ARMED_TRIGGERS, "actual trigger engine resolves the recorded armed set")
	t.ok(
		elapsed_ms <= TRIGGER_SWEEP_BUDGET_MS,
		"%d matching armed triggers resolve within %dms (took %dms)"
		% [ARMED_TRIGGERS, TRIGGER_SWEEP_BUDGET_MS, elapsed_ms],
	)


static func _actor(index: int) -> StringName:
	return StringName("state_actor.%03d" % index)


static func _state_a(index: int) -> StringName:
	return StringName("state.%03d.a" % index)


static func _state_b(index: int) -> StringName:
	return StringName("state.%03d.b" % index)
