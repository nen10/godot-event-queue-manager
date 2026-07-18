extends RefCounted
## Shared deterministic EQM-134 work-scale scenarios.
## Regression asserts semantic evidence; performance times the same work without
## duplicating setup or allowing the two lanes to drift.

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


static func setup_state_algebra() -> Dictionary:
	var lines := EQEventLines.new()
	var algebra := EQStateAlgebra.new(lines)
	var declarations: Array[bool] = []
	for pair_index in STATE_PAIRS:
		declarations.append(
			algebra.declare_inv_pair(
				_state_a(pair_index), _state_b(pair_index), EQStateAlgebra.Rule.CANCEL
			)
		)
	return {"lines": lines, "algebra": algebra, "declarations": declarations}


static func exercise_state_algebra(context: Dictionary) -> Dictionary:
	var lines = context["lines"]
	var algebra = context["algebra"]
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
	var line_snapshot: Dictionary = lines.to_dict()
	var algebra_snapshot: Dictionary = algebra.to_dict()
	var rebuilt_lines := EQEventLines.from_dict(line_snapshot)
	var rebuilt_algebra := EQStateAlgebra.from_dict(algebra_snapshot, rebuilt_lines)
	return {
		"line_snapshot": line_snapshot,
		"algebra_snapshot": algebra_snapshot,
		"rebuilt_line_snapshot": rebuilt_lines.to_dict(),
		"rebuilt_algebra_snapshot": rebuilt_algebra.to_dict(),
		"faults": algebra.faults.duplicate(true),
	}


static func setup_relation_graph() -> Dictionary:
	var graph := EQRelationGraph.new()
	var declared := graph.declare_relation_type(
		{"name": &"work_scale_link", "structure": EQRelationGraph.Structure.GRAPH}
	)
	return {"graph": graph, "declared": declared}


static func exercise_relation_graph(context: Dictionary) -> Dictionary:
	var graph = context["graph"]
	for edge_index in RELATION_EDGES:
		var from_actor := StringName("relation_actor.%03d" % (edge_index % RELATION_ACTORS))
		var to_actor := StringName(
			"relation_actor.%03d" % ((edge_index + 1) % RELATION_ACTORS)
		)
		var relation_id: StringName = graph.bind(&"work_scale_link", from_actor, to_actor)
		if relation_id == &"":
			break
	var snapshot: Dictionary = graph.to_dict()
	var rebuilt := EQRelationGraph.new()
	rebuilt.restore(snapshot)
	var expanded := rebuilt.expand(&"relation_actor.000", &"work_scale_link", 1, 1)
	return {
		"snapshot": snapshot,
		"rebuilt_snapshot": rebuilt.to_dict(),
		"expanded": expanded,
		"graph_faults": graph.faults.duplicate(true),
		"rebuilt_faults": rebuilt.faults.duplicate(true),
	}


static func setup_trigger_engine() -> Dictionary:
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
	return {"engine": engine}


static func exercise_trigger_engine(context: Dictionary) -> Dictionary:
	var fired: Array = context["engine"].on_event_resolved(
		{"kind": &"work_scale_event", "target": &"work_scale_target", "tags": []}, 0
	)
	return {"fired": fired}


static func _actor(index: int) -> StringName:
	return StringName("state_actor.%03d" % index)


static func _state_a(index: int) -> StringName:
	return StringName("state.%03d.a" % index)


static func _state_b(index: int) -> StringName:
	return StringName("state.%03d.b" % index)
